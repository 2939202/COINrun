import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../game/run_rules.dart';
import '../models/equipment_set.dart';
import '../models/run_log.dart';
import '../models/run_record.dart';
import '../models/user_model.dart';

// ============================================================
// 유저 데이터를 Firestore에 읽고 쓰는 곳
// 화면에서는 FirebaseFirestore를 직접 부르지 말고 이 클래스를 통해서만 접근합니다.
// (골드/레벨이 여기저기서 따로 관리되면 기록이 사라지는 문제가 다시 생깁니다)
// ============================================================
class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _firestore.collection('users').doc(userId);

  // 유저 문서를 실시간으로 지켜봅니다. 문서가 없으면 null을 흘려보냅니다.
  Stream<UserModel?> watchUser(String userId) {
    return _userDoc(userId).snapshots().map(
      (snapshot) =>
          snapshot.exists ? UserModel.fromMap(snapshot.data()!) : null,
    );
  }

  // 최근 러닝 기록 (최신순)
  Stream<List<RunLog>> watchRecentRuns(String userId, {int limit = 3}) {
    return _userDoc(userId)
        .collection('runs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (query) =>
              query.docs.map((doc) => RunLog.fromMap(doc.data())).toList(),
        );
  }

  // 로그인 직후에 부릅니다. 문서가 없을 때만 새로 만들고, 이미 있으면 아무것도 하지 않습니다.
  // (이미 있는데 set()으로 덮어쓰면 모아둔 골드와 레벨이 날아갑니다)
  Future<void> ensureUser(String userId, String nickname) async {
    final userDoc = _userDoc(userId);
    final snapshot = await userDoc.get();
    if (snapshot.exists) return;
    await userDoc.set(UserModel.initial(nickname).toMap());
  }

  Future<void> updateNickname(String userId, String nickname) {
    return _userDoc(userId).set({
      'nickname': nickname,
    }, SetOptions(merge: true));
  }

  // 러닝 완료 시 호출: 보상을 계산해서 유저 문서에 더하고, 러닝 기록도 남깁니다.
  // 트랜잭션을 쓰는 이유: 읽고 -> 계산하고 -> 쓰는 사이에 다른 곳에서 값이 바뀌어도
  // 골드가 덮어써져 사라지지 않도록 하기 위해서입니다.
  Future<RunReward> saveRun(String userId, RunRecord run) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      final user = UserModel.fromMap(snapshot.data() ?? {});

      // 러닝을 마친 시점에 입고 있던 장비 세트의 보너스를 얹어줍니다.
      final EquipmentSet? gear = EquipmentRules.equippedSet(user);
      final int gold = RunRules.goldFor(run, gear: gear);
      final int exp = RunRules.expFor(run, gear: gear);
      final next = RunRules.addExp(user.level, user.exp, exp);

      transaction.set(userDoc, {
        'gold': user.gold + gold,
        'level': next.level,
        'exp': next.exp,
        'totalDistance': user.totalDistance + run.distanceMeters,
        'totalRunSeconds': user.totalRunSeconds + run.elapsed.inSeconds,
        'totalMovingSeconds':
            user.totalMovingSeconds + run.movingTime.inSeconds,
        'totalSteps': user.totalSteps + run.steps,
      }, SetOptions(merge: true));

      // 러닝 기록 보관 (나중에 기록 화면, 랭킹, 부정행위 검사에 사용)
      transaction.set(userDoc.collection('runs').doc(), {
        'distanceMeters': run.distanceMeters,
        'durationSeconds': run.elapsed.inSeconds,
        'movingSeconds': run.movingTime.inSeconds,
        'steps': run.steps,
        'stepsEstimated': run.stepsEstimated, // 센서 없이 추정한 걸음인지 (부정행위 검사용)
        'goldEarned': gold,
        'expEarned': exp,
        'gearSetId': gear?.id, // 어떤 장비를 입고 뛰었는지 (나중에 기록 화면에서 사용)
        'createdAt': FieldValue.serverTimestamp(),
      });

      return RunReward(
        gold: gold,
        exp: exp,
        levelBefore: user.level,
        levelAfter: next.level,
      );
    });
  }

  // ----------------------------------------------------------
  // 장비 세트 구매 / 장착
  // ----------------------------------------------------------

  // 세트를 삽니다. 골드를 빼고, 보유 목록에 넣고, 바로 입혀줍니다.
  // 트랜잭션인 이유: 버튼을 빠르게 두 번 눌러도 골드가 두 번 빠지지 않게 하기 위해서입니다.
  Future<EquipmentSet> buySet(String userId, String setId) {
    final EquipmentSet? set = EquipmentCatalog.byId(setId);
    if (set == null) throw EquipmentException('없는 장비 세트입니다.');

    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw EquipmentException('유저 정보를 찾을 수 없습니다.');

      final user = UserModel.fromMap(snapshot.data()!);
      final check = EquipmentRules.checkPurchase(user, set);
      if (!check.isOk) throw EquipmentException(check.message(set));

      transaction.set(userDoc, {
        'gold': user.gold - set.price,
        'ownedSetIds': [...user.ownedSetIds, set.id],
        'equippedSetId': set.id,
      }, SetOptions(merge: true));

      return set;
    });
  }

  // 이미 사 둔 세트로 갈아입습니다. setId가 null이면 벗습니다.
  Future<void> equipSet(String userId, String? setId) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw EquipmentException('유저 정보를 찾을 수 없습니다.');

      final user = UserModel.fromMap(snapshot.data()!);
      if (setId != null && !user.owns(setId)) {
        throw EquipmentException('가지고 있지 않은 장비 세트입니다.');
      }

      transaction.set(userDoc, {
        'equippedSetId': setId,
      }, SetOptions(merge: true));
    });
  }
}

// 구매/장착이 실패한 이유를 화면에 그대로 보여주기 위한 예외
class EquipmentException implements Exception {
  final String message;

  const EquipmentException(this.message);

  @override
  String toString() => message;
}
