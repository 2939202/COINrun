// Firestore의 users/{userId} 문서 한 개를 나타내는 유저 데이터
class UserModel {
  final String nickname;
  final int level;
  final int exp; // 현재 레벨에서 쌓인 경험치 (레벨업하면 초과분만 남음)
  final int gold;
  final String equipment;
  final int myRank; // 전체 랭킹 순위 (등급 이름은 RunRules.tierName 참고)
  final double totalDistance; // 누적 러닝 거리 (m)
  final int totalRunSeconds; // 누적 러닝 시간 (초)
  final int totalMovingSeconds; // 누적 "움직인" 시간 (초) - 경험치 기준
  final int totalSteps; // 누적 걸음 수 - 골드 기준

  const UserModel({
    required this.nickname,
    required this.level,
    required this.exp,
    required this.gold,
    required this.equipment,
    required this.myRank,
    required this.totalDistance,
    required this.totalRunSeconds,
    required this.totalMovingSeconds,
    required this.totalSteps,
  });

  // 새로 가입한 유저의 기본값
  factory UserModel.initial(String nickname) {
    return UserModel(
      nickname: nickname,
      level: 1,
      exp: 0,
      gold: 0,
      equipment: '기본 장비',
      myRank: 0,
      totalDistance: 0,
      totalRunSeconds: 0,
      totalMovingSeconds: 0,
      totalSteps: 0,
    );
  }

  // Firestore는 숫자를 int/double 구분 없이 줄 수 있어서 num으로 받은 뒤 변환합니다.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      nickname: map['nickname'] ?? '이름없음',
      level: (map['level'] as num?)?.toInt() ?? 1,
      exp: (map['exp'] as num?)?.toInt() ?? 0,
      gold: (map['gold'] as num?)?.toInt() ?? 0,
      equipment: map['equipment'] ?? '착용 무구 없음',
      myRank: (map['myRank'] as num?)?.toInt() ?? 0,
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0,
      totalRunSeconds: (map['totalRunSeconds'] as num?)?.toInt() ?? 0,
      totalMovingSeconds: (map['totalMovingSeconds'] as num?)?.toInt() ?? 0,
      totalSteps: (map['totalSteps'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'level': level,
      'exp': exp,
      'gold': gold,
      'equipment': equipment,
      'myRank': myRank,
      'totalDistance': totalDistance,
      'totalRunSeconds': totalRunSeconds,
      'totalMovingSeconds': totalMovingSeconds,
      'totalSteps': totalSteps,
    };
  }
}
