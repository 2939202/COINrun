import '../game/character_outfit.dart';

// ============================================================
// 랭킹 목록에 보이는 한 줄
//
// Firestore의 leaderboard/{userId} 문서입니다.
// users/{userId}와 따로 두는 이유는 보안 때문입니다. users 문서는 본인만 읽을 수
// 있게 잠가두었는데, 랭킹을 보려면 남의 것도 읽어야 합니다. 그래서 남에게 보여도
// 되는 값(이름, 레벨, 누적 거리)만 이 컬렉션에 따로 복사해 둡니다.
// 골드나 이메일은 여기에 들어오지 않습니다.
// 게임 플레잉 대결에서 상대를 그리려고 겉모습(남/여, 입은 세트)도 같이 둡니다.
// ============================================================
class RankingEntry {
  final String userId;
  final String nickname;
  final int level;
  final double totalDistance; // 거리 랭킹 기준 (m)
  final int totalExp; // 레벨 랭킹 기준
  final CharacterLook? look; // 겉모습을 올리기 전 줄에는 없습니다.
  final String? equippedSetId;
  final int dogStage; // 강아지 캐릭터의 단계 (1~3)

  const RankingEntry({
    required this.userId,
    required this.nickname,
    required this.level,
    required this.totalDistance,
    required this.totalExp,
    this.look,
    this.equippedSetId,
    this.dogStage = 1,
  });

  factory RankingEntry.fromMap(String userId, Map<String, dynamic> map) {
    return RankingEntry(
      userId: userId,
      nickname: map['nickname'] ?? '이름없음',
      level: (map['level'] as num?)?.toInt() ?? 1,
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0,
      totalExp: (map['totalExp'] as num?)?.toInt() ?? 0,
      look: CharacterLook.tryParse(map['look']),
      equippedSetId: map['equippedSetId'] as String?,
      dogStage: (map['dogStage'] as num?)?.toInt() ?? 1,
    );
  }
}

// 무엇을 기준으로 줄을 세울지
enum RankingKind {
  distance('거리', 'totalDistance'),
  level('레벨', 'totalExp');

  final String label;

  // Firestore에서 정렬과 순위 세기에 쓰는 필드 이름
  final String field;

  const RankingKind(this.label, this.field);
}
