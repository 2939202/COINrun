import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../game/route_simplifier.dart';
import '../game/run_rules.dart';
import '../models/equipment_set.dart';
import '../models/run_log.dart';
import '../models/run_route.dart';
import '../models/run_record.dart';
import '../models/user_model.dart';
import 'ranking_repository.dart';

// ============================================================
// 유저 데이터를 Firestore에 읽고 쓰는 곳
// 화면에서는 FirebaseFirestore를 직접 부르지 말고 이 클래스를 통해서만 접근합니다.
// (골드/레벨이 여기저기서 따로 관리되면 기록이 사라지는 문제가 다시 생깁니다)
// ============================================================
class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  // 한 사람당 보관하는 러닝 기록 개수. 넘으면 오래된 것부터 지웁니다.
  //
  // 60개로 잡은 이유: 나중에 주간/월간 기록을 보여주려면 몇 달치가 쌓여 있어야 합니다.
  // 주 3회 뛰면 60개가 약 5개월치입니다. (20개는 7주치뿐이라 의미가 없었습니다)
  //
  // 기록 하나가 경로까지 합쳐 7KB쯤이라 60개여도 한 사람당 400KB 정도입니다.
  // 용량은 문제가 아니고, 목록을 읽을 때 따라오는 양이 신경 쓰이는 부분입니다.
  // 더 늘려야 하면 경로를 별도 문서로 빼서 목록에선 안 읽게 하는 편이 낫습니다.
  static const int maxStoredRuns = 60;

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

  CollectionReference<Map<String, dynamic>> _routes(String userId) =>
      _userDoc(userId).collection('routes');

  // 지도를 보여줄 때만 읽습니다. 목록에서는 읽지 않습니다.
  Future<RunRoute> loadRoute(String userId, String runId) async {
    final snapshot = await _routes(userId).doc(runId).get();
    return RunRoute.fromMap(snapshot.data());
  }

  // 최근 러닝 기록 (최신순)
  // 기본값은 홈의 "최근 러닝" 미리보기 개수입니다.
  // 전체 기록 화면은 limit에 maxStoredRuns를 넣어서 보관 중인 것을 전부 봅니다.
  Stream<List<RunLog>> watchRecentRuns(String userId, {int limit = 3}) {
    return _userDoc(userId)
        .collection('runs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => RunLog.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // 로그인 직후에 부릅니다. 문서가 없을 때만 새로 만들고, 이미 있으면 아무것도 하지 않습니다.
  // (이미 있는데 set()으로 덮어쓰면 모아둔 골드와 레벨이 날아갑니다)
  Future<void> ensureUser(
    String userId,
    String nickname, {
    required bool isGuest,
  }) async {
    final userDoc = _userDoc(userId);
    final snapshot = await userDoc.get();

    UserModel user;
    if (snapshot.exists) {
      user = UserModel.fromMap(snapshot.data()!);
      // 게스트였다가 이메일을 붙였으면 여기서 반영됩니다.
      if (user.isGuest != isGuest) {
        await userDoc.set({'isGuest': isGuest}, SetOptions(merge: true));
        user = UserModel.fromMap({...snapshot.data()!, 'isGuest': isGuest});
      }
    } else {
      user = UserModel.initial(nickname, isGuest: isGuest);
      await userDoc.set(user.toMap());
    }

    if (isGuest) {
      // 게스트는 랭킹에 올리지 않습니다.
      // 예전에 게스트로 올라가 있던 줄이 있으면 여기서 지웁니다.
      await RankingRepository.instance.removeEntry(userId);
    } else {
      // 로그인할 때마다 올리므로, 랭킹을 붙이기 전부터 쓰던 계정도 여기서 들어옵니다.
      await RankingRepository.instance.publish(userId, user);
    }
  }

  // 회원 탈퇴 - 이 계정이 만든 것을 전부 지웁니다.
  //
  // 지우는 순서가 중요합니다. 랭킹 줄을 먼저 지워야, 중간에 실패해도
  // "주인 없는 랭킹 줄"이 남지 않습니다. 남은 것은 다시 불러서 마저 지우면 됩니다.
  Future<void> deleteAccountData(String userId) async {
    await RankingRepository.instance.removeEntry(userId);

    // 러닝 기록과 경로는 문서가 여러 개라 나눠서 지웁니다.
    // (한 번에 지울 수 있는 개수에 한도가 있습니다)
    await _deleteAll(_userDoc(userId).collection('runs'));
    await _deleteAll(_routes(userId));

    await _userDoc(userId).delete();
  }

  Future<void> _deleteAll(
    CollectionReference<Map<String, dynamic>> target,
  ) async {
    while (true) {
      final found = await target
          .limit(100)
          .get(const GetOptions(source: Source.server));
      if (found.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in found.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> updateNickname(String userId, String nickname) async {
    await _userDoc(userId).set({'nickname': nickname}, SetOptions(merge: true));
    // 게스트는 랭킹에 줄이 없어서 고칠 것도 없습니다. (없는 줄을 고쳐도 탈은 없음)
    await RankingRepository.instance.renameEntry(userId, nickname);
  }

  // 러닝 완료 시 호출: 보상을 계산해서 유저 문서에 더하고, 러닝 기록도 남깁니다.
  // 트랜잭션을 쓰는 이유: 읽고 -> 계산하고 -> 쓰는 사이에 다른 곳에서 값이 바뀌어도
  // 골드가 덮어써져 사라지지 않도록 하기 위해서입니다.
  Future<RunReward> saveRun(String userId, RunRecord run) async {
    final RunReward reward = await _saveRunInTransaction(userId, run);

    // 오래된 기록 정리는 보상 저장과 따로 합니다.
    // 정리하다 실패해도 이미 받은 보상이 사라지면 안 되기 때문입니다.
    try {
      await _pruneOldRuns(userId);
    } catch (error) {
      // 다음 러닝 때 다시 정리하면 됩니다.
      debugPrint('오래된 기록 정리 실패: $error');
    }

    return reward;
  }

  // 보관 개수를 넘은 만큼 오래된 기록부터 지웁니다.
  Future<void> _pruneOldRuns(String userId) async {
    final runs = _userDoc(userId).collection('runs');

    // 문서를 받아오지 않고 개수만 셉니다.
    final int total = (await runs.count().get()).count ?? 0;
    final int extra = total - maxStoredRuns;
    if (extra <= 0) return;

    // 캐시가 아니라 서버에서 읽습니다. 지우는 작업이라 오래된 값으로 판단하면 안 됩니다.
    final oldest = await runs
        .orderBy('createdAt')
        .limit(extra)
        .get(const GetOptions(source: Source.server));

    final batch = _firestore.batch();
    for (final doc in oldest.docs) {
      batch.delete(doc.reference);
      // 경로는 같은 id로 따로 저장돼 있습니다. 같이 지우지 않으면 주인 없는 경로가 남습니다.
      batch.delete(_routes(userId).doc(doc.id));
    }
    await batch.commit();
  }

  Future<RunReward> _saveRunInTransaction(String userId, RunRecord run) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      final user = UserModel.fromMap(snapshot.data() ?? {});

      // 러닝을 마친 시점에 입고 있던 장비 세트의 보너스를 얹어줍니다.
      final EquipmentSet? gear = EquipmentRules.equippedSet(user);
      final int gold = RunRules.goldFor(run, gear: gear);
      final int exp = RunRules.expFor(run, gear: gear);
      final next = RunRules.addExp(user.level, user.exp, exp);

      final double totalDistance = user.totalDistance + run.distanceMeters;
      final int totalExp = user.totalExp + exp;

      transaction.set(userDoc, {
        'gold': user.gold + gold,
        'level': next.level,
        'exp': next.exp,
        'totalDistance': totalDistance,
        'totalRunSeconds': user.totalRunSeconds + run.elapsed.inSeconds,
        'totalMovingSeconds':
            user.totalMovingSeconds + run.movingTime.inSeconds,
        'totalSteps': user.totalSteps + run.steps,
        'totalExp': totalExp,
      }, SetOptions(merge: true));

      // 랭킹 목록도 같은 트랜잭션에서 갱신합니다.
      // 따로 쓰면 한쪽만 성공해서 순위가 실제 기록과 어긋날 수 있습니다.
      //
      // 게스트는 올리지 않습니다. 기록은 평소대로 쌓이고, 나중에 이메일을 붙이면
      // 그동안의 누적 거리와 경험치를 그대로 들고 랭킹에 들어갑니다.
      if (!user.isGuest) {
        transaction.set(
          RankingRepository.instance.entryDoc(userId),
          RankingRepository.entryData(
            nickname: user.nickname,
            level: next.level,
            totalDistance: totalDistance,
            totalExp: totalExp,
          ),
          SetOptions(merge: true),
        );
      }

      // 러닝 기록과 경로를 같은 id로 나눠서 담습니다.
      // 문서 이름을 미리 받아두면 두 곳에 같은 id를 쓸 수 있습니다.
      final runRef = userDoc.collection('runs').doc();

      // 경로는 무겁고 목록에서는 쓰지 않아서 따로 둡니다. (models/run_route.dart 참고)
      // 점이 수천 개라 그대로 담으면 문서가 너무 커져서 솎아내고 저장합니다.
      transaction.set(
        _routes(userId).doc(runRef.id),
        RunRoute.toFields(RouteSimplifier.simplifySegments(run.segments)),
      );

      // 러닝 기록 보관 (나중에 기록 화면, 랭킹, 부정행위 검사에 사용)
      transaction.set(runRef, {
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
