import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/run_rules.dart';
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

  // 로그인 기능을 붙이기 전까지 사용하는 테스트 유저
  static const String testUserId = 'user_test_01';

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

  Future<void> createUser(String userId, String nickname) {
    return _userDoc(userId).set(UserModel.initial(nickname).toMap());
  }

  // 러닝 완료 시 호출: 보상을 계산해서 유저 문서에 더하고, 러닝 기록도 남깁니다.
  // 트랜잭션을 쓰는 이유: 읽고 -> 계산하고 -> 쓰는 사이에 다른 곳에서 값이 바뀌어도
  // 골드가 덮어써져 사라지지 않도록 하기 위해서입니다.
  Future<RunReward> saveRun(String userId, RunRecord run) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      final user = UserModel.fromMap(snapshot.data() ?? {});

      final int gold = RunRules.goldFor(run);
      final int exp = RunRules.expFor(run);
      final next = RunRules.addExp(user.level, user.exp, exp);

      transaction.set(userDoc, {
        'gold': user.gold + gold,
        'level': next.level,
        'exp': next.exp,
        'totalDistance': user.totalDistance + run.distanceMeters,
        'totalRunSeconds': user.totalRunSeconds + run.elapsed.inSeconds,
      }, SetOptions(merge: true));

      // 러닝 기록 보관 (나중에 기록 화면, 랭킹, 부정행위 검사에 사용)
      transaction.set(userDoc.collection('runs').doc(), {
        'distanceMeters': run.distanceMeters,
        'durationSeconds': run.elapsed.inSeconds,
        'goldEarned': gold,
        'expEarned': exp,
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
}
