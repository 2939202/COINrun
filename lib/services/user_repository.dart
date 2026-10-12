import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../game/backdrop_catalog.dart';
import '../game/character_outfit.dart';
import '../game/course_coins.dart';
import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../game/pet_catalog.dart';
import '../game/route_simplifier.dart';
import '../game/run_totals.dart';
import '../game/stats_period.dart';
import '../game/run_load.dart';
import '../game/run_rules.dart';
import '../models/equipment_set.dart';
import '../models/run_log.dart';
import '../models/run_route.dart';
import '../models/run_stats.dart';
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

  // 휴지통은 러닝 기록과 따로 셉니다. 버린 것이 쌓여서 멀쩡한 기록을 밀어내면 안 됩니다.
  static const int maxTrashedRuns = 60;

  // 버린 지 이만큼 지나면 알아서 완전히 지웁니다.
  static const int trashKeepDays = 7;

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

  CollectionReference<Map<String, dynamic>> _stats(String userId) =>
      _userDoc(userId).collection('stats');

  // 주간/월간 요약을 최근 것부터 읽습니다. (화면은 나중에 만듭니다)
  Stream<List<RunStats>> watchStats(
    String userId, {
    required bool weekly,
    int limit = 12,
  }) {
    return _stats(userId)
        .where('isWeek', isEqualTo: weekly)
        .orderBy('startAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => RunStats.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // 요약 칸을 이름으로 콕 집어 읽습니다. (AI 평가에서 씀)
  //
  // watchStats처럼 isWeek로 거르고 startAt으로 정렬하면 Firestore에 복합 색인을 따로
  // 만들어야 합니다. 이름으로 읽으면 색인이 필요 없고, 뛰지 않은 기간은 그냥 빠집니다.
  // whereIn은 한 번에 30개까지라 그 안에서만 씁니다.
  Stream<Map<String, RunStats>> watchStatsByKeys(
    String userId,
    List<String> keys,
  ) {
    assert(keys.isNotEmpty && keys.length <= 30);
    return _stats(userId)
        .where(FieldPath.documentId, whereIn: keys)
        .snapshots()
        .map(
          (query) => {
            for (final doc in query.docs)
              doc.id: RunStats.fromMap(doc.id, doc.data()),
          },
        );
  }

  // 휴지통은 별도 컬렉션입니다.
  //
  // 같은 collection에 표시만 해두면 "버리지 않은 것만 60개" 같은 조건을 Firestore에
  // 물어보기가 어렵습니다. (없는 필드를 기준으로는 거를 수 없습니다)
  // 아예 옮겨두면 양쪽 개수를 따로 세는 일이 그냥 됩니다.
  CollectionReference<Map<String, dynamic>> _trash(String userId) =>
      _userDoc(userId).collection('trash');

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
              // 감춘 기록은 목록에서 뺍니다.
              //
              // 질의로 거르지 않고 여기서 거르는 이유: Firestore에서 "hidden이 true가
              // 아닌 것"을 물으면 hidden 필드가 아예 없는 옛 기록까지 빠져버립니다.
              // 어차피 60개 안쪽이라 받아와서 거르는 편이 안전합니다.
              .where((log) => !log.hidden && !log.isInTrash)
              .toList(),
        );
  }

  // start 이상 end 미만에 저장된 기록 (AI 평가의 달력). 감춘 기록은 뺍니다.
  Stream<List<RunLog>> watchRunsBetween(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return _userDoc(userId)
        .collection('runs')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => RunLog.fromMap(doc.id, doc.data()))
              .where((log) => !log.hidden && !log.isInTrash)
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

  // 주간/월간 요약 칸에 더하거나(sign 1) 뺍니다(sign -1).
  void _applyStats({
    required Transaction transaction,
    required String userId,
    required DateTime at,
    required double distanceMeters,
    required int seconds,
    required int movingSeconds,
    required int steps,
    required int gold,
    required int exp,
    int sign = 1,
  }) {
    final stats = _stats(userId);
    final periods = <String, ({DateTime start, bool isWeek})>{
      StatsPeriod.weekKey(at): (start: StatsPeriod.weekStart(at), isWeek: true),
      StatsPeriod.monthKey(at): (
        start: StatsPeriod.monthStart(at),
        isWeek: false,
      ),
    };

    for (final entry in periods.entries) {
      transaction.set(
        stats.doc(entry.key),
        RunStats.changes(
          startAt: entry.value.start,
          isWeek: entry.value.isWeek,
          distanceMeters: distanceMeters,
          seconds: seconds,
          movingSeconds: movingSeconds,
          steps: steps,
          gold: gold,
          exp: exp,
          sign: sign,
        ),
        SetOptions(merge: true),
      );
    }
  }

  // 휴지통에 있는 기록만 (버린 지 오래된 것부터가 아니라 최근에 버린 것부터)
  Stream<List<RunLog>> watchTrash(String userId) {
    return _trash(userId)
        .orderBy('deletedAt', descending: true)
        .limit(maxTrashedRuns)
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => RunLog.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> setTrashEnabled(String userId, bool enabled) {
    return _userDoc(
      userId,
    ).set({'trashEnabled': enabled}, SetOptions(merge: true));
  }

  // 홈의 "시작"이 러닝과 코스 러닝 중 어디로 갈지 기억해 둡니다. (UserModel.prefersCourseRun)
  //
  // 화면 전환을 기다리게 하지 않으려고 부른 쪽에서 await하지 않습니다.
  // 실패해도 다음 시작 때 원래 쪽으로 갈 뿐이라 오류는 로그만 남깁니다.
  void setPrefersCourseRun(String userId, bool course) {
    _userDoc(userId)
        .set({'prefersCourseRun': course}, SetOptions(merge: true))
        .catchError((Object error) => debugPrint('러닝 방식 저장 실패: $error'));
  }

  // 캐릭터 모습(남/여)을 저장합니다. (UserModel.look) 내 캐릭터 화면에서 바꿉니다.
  Future<void> setLook(String userId, CharacterLook look) async {
    final userDoc = _userDoc(userId);
    final UserModel? user = await _firestore.runTransaction((
      transaction,
    ) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) return null;
      transaction.set(userDoc, {'look': look.id}, SetOptions(merge: true));
      return UserModel.fromMap({...snapshot.data()!, 'look': look.id});
    });
    // 대결 상대 목록에도 겉모습을 올립니다. 게스트는 랭킹에 없으므로 건너뜁니다.
    if (user != null && !user.isGuest) {
      await RankingRepository.instance
          .entryDoc(userId)
          .set(
            RankingRepository.appearanceData(
              look: look,
              setId: user.visibleSetId,
              dogStage: user.dogStage,
            ),
            SetOptions(merge: true),
          );
    }
  }

  // 시연용: 레벨 10, 골드 30,000으로 맞춥니다. (홈의 골드를 빠르게 6번)
  // 누적 경험치는 레벨 10에 맞는 값보다 낮을 때만 올려서, 레벨 랭킹이 거꾸로 가지 않게 합니다.
  static const int demoLevel = 10;
  static const int demoGold = 30000;

  Future<void> grantDemo(String userId) async {
    final userDoc = _userDoc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) return;
      final UserModel user = UserModel.fromMap(snapshot.data()!);
      final int totalExp = max(
        user.totalExp,
        RunRules.totalExpFor(demoLevel, 0),
      );
      transaction.set(userDoc, {
        'level': demoLevel,
        'exp': 0,
        'gold': demoGold,
        'totalExp': totalExp,
      }, SetOptions(merge: true));
      _logLevels(transaction, userId, user.level, demoLevel);
      if (!user.isGuest) {
        transaction.set(
          RankingRepository.instance.entryDoc(userId),
          RankingRepository.entryData(
            nickname: user.nickname,
            level: demoLevel,
            totalDistance: user.totalDistance,
            totalExp: totalExp,
          ),
          SetOptions(merge: true),
        );
      }
    });
  }

  // ----------------------------------------------------------
  // 레벨 돌파 기록 (users/{uid}/levels/{레벨})
  //
  // 레벨이 오를 때마다 그 레벨에 처음 닿은 때를 적어 둡니다. 플레이어 카드에서 보여줍니다.
  // 이 기능을 넣기 전에 오른 레벨은 기록이 없습니다.
  // ----------------------------------------------------------
  void _logLevels(Transaction transaction, String userId, int from, int to) {
    for (int level = from + 1; level <= to; level++) {
      transaction.set(_userDoc(userId).collection('levels').doc('$level'), {
        'level': level,
        'reachedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // (레벨, 닿은 때) 높은 레벨부터
  Stream<List<(int, DateTime?)>> watchLevelLog(String userId) {
    return _userDoc(userId)
        .collection('levels')
        .orderBy('level', descending: true)
        .snapshots()
        .map(
          (query) => [
            for (final doc in query.docs)
              (
                (doc.data()['level'] as num?)?.toInt() ?? 0,
                (doc.data()['reachedAt'] as Timestamp?)?.toDate(),
              ),
          ],
        );
  }

  // 목록에서만 감춥니다. 통계와 보상은 그대로 둡니다.
  Future<void> hideRun(String userId, String runId) {
    return _userDoc(userId).collection('runs').doc(runId).set({
      'hidden': true,
    }, SetOptions(merge: true));
  }

  // 기록 하나를 목록에서 없앱니다.
  //
  // toTrash가 true면 휴지통 컬렉션으로 옮기고, false면 경로까지 바로 지웁니다.
  // 어느 쪽이든 주간/월간 요약과 홈의 누적 기록(거리·시간·걸음, 거리 랭킹)에서는 그 자리에서
  // 빼냅니다. "삭제하면 빠집니다"라고 알려놓고 휴지통에 있는 동안 계속 세고 있으면 말이 다르기 때문입니다.
  //
  // 받은 골드와 경험치는 건드리지 않습니다. 이미 그 골드로 장비를 샀을 수 있어서,
  // 되돌리려다 골드가 마이너스가 되는 쪽이 더 이상합니다.
  Future<void> removeRun(
    String userId,
    RunLog run, {
    required bool toTrash,
  }) async {
    final runRef = _userDoc(userId).collection('runs').doc(run.id);

    await _applyStatsAndMove(
      userId: userId,
      run: run,
      sign: -1,
      // 휴지통으로 옮길 원본을 복사하려고, 그리고 이미 지워진 기록을 두 번 빼지 않으려고 먼저 읽습니다.
      readRef: runRef,
      write: (transaction, source) {
        if (toTrash) {
          transaction.set(_trash(userId).doc(run.id), {
            ...?source,
            'deletedAt': FieldValue.serverTimestamp(),
          });
          // 경로는 지우지 않습니다. 되살렸을 때 지도가 그대로 보여야 합니다.
        } else {
          transaction.delete(_routes(userId).doc(run.id));
        }
        transaction.delete(runRef);
      },
    );
  }

  // 휴지통에서 되살립니다. 요약에도 다시 더합니다.
  Future<void> restoreRun(String userId, RunLog run) async {
    final trashRef = _trash(userId).doc(run.id);

    await _applyStatsAndMove(
      userId: userId,
      run: run,
      sign: 1,
      readRef: trashRef,
      write: (transaction, source) {
        transaction.set(
          _userDoc(userId).collection('runs').doc(run.id),
          Map<String, dynamic>.from(source!)..remove('deletedAt'),
        );
        transaction.delete(trashRef);
      },
    );
  }

  // 휴지통에서 완전히 지웁니다. 요약에서는 버릴 때 이미 뺐으므로 건드리지 않습니다.
  Future<void> purgeRuns(String userId, List<RunLog> runs) async {
    await _purgeTrashDocs(userId, runs.map((run) => run.id).toList());
  }

  Future<void> _purgeTrashDocs(String userId, List<String> ids) async {
    if (ids.isEmpty) return;

    // 한 번에 담을 수 있는 개수에 한도가 있어서 나눠서 지웁니다.
    for (int i = 0; i < ids.length; i += 100) {
      final batch = _firestore.batch();
      for (final id in ids.skip(i).take(100)) {
        batch.delete(_trash(userId).doc(id));
        batch.delete(_routes(userId).doc(id));
      }
      await batch.commit();
    }
  }

  // 버린 지 오래된 것과, 한도를 넘은 만큼을 정리합니다.
  //
  // 서버가 따로 없어서 앱이 할 일입니다. 러닝을 저장할 때와 휴지통을 열 때 부릅니다.
  Future<void> pruneTrash(String userId) async {
    final trash = _trash(userId);

    // 1. 기한이 지난 것
    final cutoff = DateTime.now().subtract(const Duration(days: trashKeepDays));
    final expired = await trash
        .where('deletedAt', isLessThan: Timestamp.fromDate(cutoff))
        .limit(100)
        .get(const GetOptions(source: Source.server));
    await _purgeTrashDocs(userId, expired.docs.map((doc) => doc.id).toList());

    // 2. 그러고도 한도를 넘으면 오래 버려둔 것부터
    final int total = (await trash.count().get()).count ?? 0;
    final int extra = total - maxTrashedRuns;
    if (extra <= 0) return;

    final oldest = await trash
        .orderBy('deletedAt')
        .limit(extra)
        .get(const GetOptions(source: Source.server));
    await _purgeTrashDocs(userId, oldest.docs.map((doc) => doc.id).toList());
  }

  // 요약과 누적 기록에서 빼거나(-1) 더하면서(+1) 기록 문서를 옮깁니다.
  //
  // 트랜잭션은 읽기를 모두 끝낸 뒤에야 쓸 수 있어서, 옮길 원본을 읽는 일도 여기서 합니다.
  // 원본이 이미 없으면(삭제를 두 번 눌렀거나 휴지통에서 이미 지워짐) 아무것도 하지 않습니다.
  // 그대로 진행하면 같은 기록을 두 번 빼게 됩니다.
  Future<void> _applyStatsAndMove({
    required String userId,
    required RunLog run,
    required int sign,
    required DocumentReference<Map<String, dynamic>> readRef,
    required void Function(
      Transaction transaction,
      Map<String, dynamic>? source,
    )
    write,
  }) async {
    final DateTime at = run.createdAt ?? DateTime.now();
    final userDoc = _userDoc(userId);
    final stats = _stats(userId);
    final weekRef = stats.doc(StatsPeriod.weekKey(at));
    final monthRef = stats.doc(StatsPeriod.monthKey(at));

    await _firestore.runTransaction((transaction) async {
      // --- 읽기 ---
      final source = await transaction.get(readRef);
      if (!source.exists) return;
      final userSnapshot = await transaction.get(userDoc);
      final weekSnapshot = await transaction.get(weekRef);
      final monthSnapshot = await transaction.get(monthRef);

      // --- 쓰기 ---
      // 홈의 총 킬로미터·총 시간과 거리 랭킹. 골드·경험치·레벨은 그대로 둡니다. (removeRun 설명 참고)
      if (userSnapshot.exists) {
        final user = UserModel.fromMap(userSnapshot.data()!);
        final totals = RunTotals.apply(user, run, sign);
        transaction.set(userDoc, totals.toMap(), SetOptions(merge: true));
        if (!user.isGuest) {
          transaction.set(RankingRepository.instance.entryDoc(userId), {
            'totalDistance': totals.distanceMeters,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // 요약을 붙이기 전에 저장된 러닝은 요약에 들어간 적이 없습니다.
      // 없는 칸을 손대면 "-1회, -5km"짜리 칸이 새로 생겨버립니다.
      final periods = [
        (
          ref: weekRef,
          exists: weekSnapshot.exists,
          start: StatsPeriod.weekStart(at),
          isWeek: true,
        ),
        (
          ref: monthRef,
          exists: monthSnapshot.exists,
          start: StatsPeriod.monthStart(at),
          isWeek: false,
        ),
      ];

      for (final period in periods) {
        if (!period.exists) continue;
        transaction.set(
          period.ref,
          RunStats.changes(
            startAt: period.start,
            isWeek: period.isWeek,
            distanceMeters: run.distanceMeters,
            seconds: run.durationSeconds,
            movingSeconds: run.movingSeconds,
            steps: run.steps,
            gold: run.goldEarned,
            exp: run.expEarned,
            sign: sign,
          ),
          SetOptions(merge: true),
        );
      }

      write(transaction, source.data());
    });
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
    await _deleteAll(_stats(userId));
    await _deleteAll(_trash(userId));
    // AI 비서가 쓴 평가 저장본과 이번 주 목표
    await _deleteAll(_userDoc(userId).collection('insights'));
    await _deleteAll(_userDoc(userId).collection('goals'));
    await _deleteAll(_userDoc(userId).collection('levels'));
    // 예전 버전이 넣어 둔 우편도 지웁니다.
    await _deleteAll(_userDoc(userId).collection('mail'));

    // 내가 만든 사설 코스. 코스 아래 하트 기록부터 지워야 주인 없는 문서가 남지 않습니다.
    // (내가 남의 코스에 누른 하트는 남습니다. 찾으려면 컬렉션 그룹 색인이 따로 필요합니다)
    final mine = await _firestore
        .collection('courses')
        .where('authorId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    for (final course in mine.docs) {
      await _deleteAll(course.reference.collection('hearts'));
      await course.reference.delete();
    }

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
  //
  // course: 코스 러닝이었으면 먹은 코인. 이때 골드는 코인으로만 줍니다.
  // 완료 창에서 사용자가 고른(또는 그대로 둔) 부하도를 기록에 적습니다.
  // 계산값(loadLevel)은 그대로 두고 따로 적어서, 둘의 차이로 개인 보정을 할 수 있게 합니다.
  Future<void> saveFeltLoad(
    String userId,
    String runId, {
    required int level,
    required int computedLevel,
  }) {
    return _userDoc(userId).collection('runs').doc(runId).update({
      'feltLevel': level,
      'feltLevelEdited': level != computedLevel,
    });
  }

  Future<RunReward> saveRun(
    String userId,
    RunRecord run, {
    CourseResult? course,
    RunLoad? load,
  }) async {
    final RunReward reward = await _saveRunInTransaction(
      userId,
      run,
      course,
      load,
    );

    // 오래된 기록 정리는 보상 저장과 따로 합니다.
    // 정리하다 실패해도 이미 받은 보상이 사라지면 안 되기 때문입니다.
    try {
      await _pruneOldRuns(userId);
      await pruneTrash(userId);
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

  Future<RunReward> _saveRunInTransaction(
    String userId,
    RunRecord run,
    CourseResult? course,
    RunLoad? load,
  ) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      final user = UserModel.fromMap(snapshot.data() ?? {});

      // 러닝을 마친 시점에 입고 있던 장비 세트의 보너스를 얹어줍니다.
      final EquipmentSet? gear = EquipmentRules.equippedSet(user);
      final int gold = course == null
          ? RunRules.goldFor(run, gear: gear)
          : RunRules.courseGoldFor(course.gold, gear: gear);
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
      _logLevels(transaction, userId, user.level, next.level);

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
        // 코스 러닝이면 어느 코스에서 코인을 몇 개 먹었는지
        if (course != null) ...{
          'courseId': course.courseId,
          'coinsCollected': course.coinsCollected,
          'coinsTotal': course.coinsTotal,
          'courseCompleted': course.completed,
        },
        // 이번 러닝의 부하도 (game/run_load.dart). AI 분석과 기록 화면에서 씁니다.
        if (load != null) ...load.toMap(),
        'hidden': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 이번 주 칸과 이번 달 칸에 더해둡니다.
      //
      // 여기서 더해두면 나중에 "이번 주 얼마나 뛰었지"를 볼 때 러닝 기록을 뒤지지 않고
      // 문서 하나만 읽으면 됩니다. 상세 기록이 60개를 넘어 밀려나도 이 숫자는 남습니다.
      _applyStats(
        transaction: transaction,
        userId: userId,
        at: DateTime.now(),
        distanceMeters: run.distanceMeters,
        seconds: run.elapsed.inSeconds,
        movingSeconds: run.movingTime.inSeconds,
        steps: run.steps,
        gold: gold,
        exp: exp,
      );

      return RunReward(
        gold: gold,
        exp: exp,
        levelBefore: user.level,
        levelAfter: next.level,
        runId: runRef.id,
      );
    });
  }

  // ----------------------------------------------------------
  // 장비 세트 구매 / 장착
  // ----------------------------------------------------------

  // 세트를 삽니다. 골드를 빼고, 보유 목록에 넣고, 바로 입혀줍니다.
  // 능력치 옷과 보이는 옷을 둘 다 새 옷으로 바꿉니다. (보이는 옷은 능력치 옷을 따라감)
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
        'outfitSetId': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (!user.isGuest) {
        transaction.set(
          RankingRepository.instance.entryDoc(userId),
          RankingRepository.appearanceData(look: user.look, setId: set.id),
          SetOptions(merge: true),
        );
      }

      return set;
    });
  }

  // 능력치 옷을 바꿉니다. setId가 null이면 기본 옷(능력치 없음)입니다.
  // 보이는 옷을 따로 정해 두지 않았으면 겉모습도 같이 바뀝니다.
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
      // 대결 상대 목록에도 보이는 옷을 올립니다. 게스트는 랭킹에 없으므로 건너뜁니다.
      final UserModel after = UserModel.fromMap({
        ...snapshot.data()!,
        'equippedSetId': setId,
      });
      if (!user.isGuest) {
        transaction.set(
          RankingRepository.instance.entryDoc(userId),
          RankingRepository.appearanceData(
            look: user.look,
            setId: after.visibleSetId,
          ),
          SetOptions(merge: true),
        );
      }
    });
  }

  // 보이는 옷을 바꿉니다. setId가 null이면 기본 옷입니다. 능력치는 그대로입니다.
  Future<void> wearOutfit(String userId, String? setId) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw EquipmentException('유저 정보를 찾을 수 없습니다.');

      final user = UserModel.fromMap(snapshot.data()!);
      if (setId != null && !user.owns(setId)) {
        throw EquipmentException('가지고 있지 않은 옷입니다.');
      }

      transaction.set(userDoc, {
        'outfitSetId': setId ?? UserModel.basicOutfit,
      }, SetOptions(merge: true));
      if (!user.isGuest) {
        transaction.set(
          RankingRepository.instance.entryDoc(userId),
          RankingRepository.appearanceData(look: user.look, setId: setId),
          SetOptions(merge: true),
        );
      }
    });
  }

  // ----------------------------------------------------------
  // 간식과 강아지 (game/pet_catalog.dart)
  // ----------------------------------------------------------

  // 간식을 count개 삽니다. 한 번에 1~50개, 하나에 80골드씩.
  Future<void> buySnack(String userId, int count) {
    final userDoc = _userDoc(userId);
    if (count < 1 || count > PetCatalog.maxPerPurchase) {
      throw EquipmentException(
        '한 번에 1~${PetCatalog.maxPerPurchase}개까지 살 수 있어요.',
      );
    }
    final int price = PetCatalog.snackPrice * count;

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw EquipmentException('유저 정보를 찾을 수 없습니다.');

      final user = UserModel.fromMap(snapshot.data()!);
      if (user.gold < price) throw EquipmentException('골드가 모자라요.');

      transaction.set(userDoc, {
        'gold': user.gold - price,
        'snacks': user.snacks + count,
      }, SetOptions(merge: true));
    });
  }

  // ----------------------------------------------------------
  // 내 캐릭터 배경 (game/backdrop_catalog.dart)
  // ----------------------------------------------------------

  // 배경을 삽니다. 사자마자 그 배경으로 바꿔 줍니다.
  Future<void> buyBackdrop(String userId, Backdrop backdrop) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw EquipmentException('유저 정보를 찾을 수 없습니다.');

      final user = UserModel.fromMap(snapshot.data()!);
      if (user.ownsBackdrop(backdrop)) {
        throw EquipmentException('이미 가진 배경입니다.');
      }
      if (user.gold < backdrop.price) throw EquipmentException('골드가 모자라요.');

      transaction.set(userDoc, {
        'gold': user.gold - backdrop.price,
        'ownedBackdrops': [...user.ownedBackdrops, backdrop.id],
        'backdrop': backdrop.id,
      }, SetOptions(merge: true));
    });
  }

  // 배경을 바꿉니다. 가진 배경만 고를 수 있습니다.
  Future<void> setBackdrop(String userId, Backdrop backdrop) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw EquipmentException('유저 정보를 찾을 수 없습니다.');

      final user = UserModel.fromMap(snapshot.data()!);
      if (!user.ownsBackdrop(backdrop)) {
        throw EquipmentException('가지고 있지 않은 배경입니다.');
      }

      transaction.set(userDoc, {
        'backdrop': backdrop.id,
      }, SetOptions(merge: true));
    });
  }

  // 강아지에게 이름을 지어 줍니다. 빈 이름이면 지웁니다. (최대 10자)
  Future<void> setDogName(String userId, CharacterLook dog, String name) {
    final String trimmed = name.trim();
    final String clipped = trimmed.length > 10
        ? trimmed.substring(0, 10)
        : trimmed;
    return _userDoc(userId).set({
      'dogNames': {dog.id: clipped},
    }, SetOptions(merge: true));
  }

  // 강아지 캐릭터에게 간식을 하나 줍니다. 다 자란 강아지도 먹을 수는 있습니다.
  // 지금 쓰는 캐릭터가 그 강아지면 대결 상대 목록의 단계도 맞춥니다.
  Future<void> feedPet(String userId, CharacterLook pet) {
    final userDoc = _userDoc(userId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw EquipmentException('유저 정보를 찾을 수 없습니다.');

      final user = UserModel.fromMap(snapshot.data()!);
      if (user.snacks <= 0) {
        throw EquipmentException('간식이 없어요. 잡화점에서 살 수 있어요.');
      }

      final int fed = user.fedOf(pet.id) + 1;
      transaction.set(userDoc, {
        'snacks': user.snacks - 1,
        'petFed': {...user.petFed, pet.id: fed},
      }, SetOptions(merge: true));
      if (!user.isGuest && user.look == pet) {
        transaction.set(RankingRepository.instance.entryDoc(userId), {
          'dogStage': PetCatalog.stageFor(fed),
        }, SetOptions(merge: true));
      }
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
