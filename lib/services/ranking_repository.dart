import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/character_outfit.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';

// ============================================================
// 랭킹을 읽고 쓰는 곳 (Firestore의 leaderboard 컬렉션)
//
// [내 순위를 어떻게 구하나]
//   전체를 받아와서 세면 사람이 늘수록 느려지고 돈도 듭니다. 대신 Firestore의
//   count() 집계 질의로 "나보다 앞선 사람이 몇 명인가"만 물어봅니다.
//   문서를 실제로 받아오지 않아서 사람이 몇 만 명이어도 빠릅니다.
//   앞선 사람이 3명이면 내가 4등입니다.
// ============================================================
class RankingRepository {
  RankingRepository._();

  static final RankingRepository instance = RankingRepository._();

  // 목록에 한 번에 보여주는 인원
  static const int topLimit = 50;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _board =>
      _firestore.collection('leaderboard');

  // 상위 몇 명
  Stream<List<RankingEntry>> watchTop(
    RankingKind kind, {
    int limit = topLimit,
  }) {
    return _board
        .orderBy(kind.field, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (query) => query.docs
              .map((doc) => RankingEntry.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // 내 순위 (1등이면 1). 아직 한 번도 안 뛰었으면 null입니다.
  Future<int?> myRank(RankingKind kind, UserModel user) async {
    // 게스트는 랭킹에 줄이 없어서 순위도 없습니다.
    if (user.isGuest) return null;

    final num mine = switch (kind) {
      RankingKind.distance => user.totalDistance,
      RankingKind.level => user.totalExp,
    };
    if (mine <= 0) return null;

    final snapshot = await _board
        .where(kind.field, isGreaterThan: mine)
        .count()
        .get();
    final int? ahead = snapshot.count;
    return ahead == null ? null : ahead + 1;
  }

  // 내 랭킹 정보를 최신으로 맞춥니다.
  //
  // 러닝을 저장할 때, 로그인할 때, 닉네임을 바꿀 때 부릅니다.
  // users 문서가 진짜이고 이쪽은 보여주기용 복사본이라, 늦게 반영돼도 큰 문제는 없습니다.
  Future<void> publish(String userId, UserModel user) {
    return _board.doc(userId).set({
      ...entryData(
        nickname: user.nickname,
        level: user.level,
        totalDistance: user.totalDistance,
        totalExp: user.totalExp,
      ),
      ...appearanceData(look: user.look, setId: user.equippedSetId),
    }, SetOptions(merge: true));
  }

  // 러닝을 저장하는 트랜잭션 안에서도 같은 내용을 쓰기 위해 따로 빼두었습니다.
  static Map<String, dynamic> entryData({
    required String nickname,
    required int level,
    required double totalDistance,
    required int totalExp,
  }) {
    return {
      'nickname': nickname,
      'level': level,
      'totalDistance': totalDistance,
      'totalExp': totalExp,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // 게임 플레잉 대결에서 상대 캐릭터를 그리는 데 쓰는 겉모습 (남/여, 입은 세트)
  static Map<String, dynamic> appearanceData({
    required CharacterLook? look,
    required String? setId,
  }) {
    return {if (look != null) 'look': look.id, 'equippedSetId': setId};
  }

  DocumentReference<Map<String, dynamic>> entryDoc(String userId) =>
      _board.doc(userId);

  // 랭킹에서 뺍니다. 탈퇴했거나, 게스트로 쓰는 중일 때 부릅니다.
  // 없는 줄을 지워도 오류가 나지 않아서 그냥 불러도 됩니다.
  Future<void> removeEntry(String userId) => _board.doc(userId).delete();

  Future<void> renameEntry(String userId, String nickname) {
    return _board.doc(userId).set({
      'nickname': nickname,
    }, SetOptions(merge: true));
  }
}
