import '../game/run_rules.dart';

// Firestore의 users/{userId} 문서 한 개를 나타내는 유저 데이터
class UserModel {
  final String nickname;
  final int level;
  final int exp; // 현재 레벨에서 쌓인 경험치 (레벨업하면 초과분만 남음)
  final int gold;

  // 장비는 세트 단위입니다. (game/equipment_catalog.dart의 id를 저장합니다)
  final List<String> ownedSetIds; // 사 둔 세트들
  final String? equippedSetId; // 지금 입고 있는 세트. null이면 맨몸입니다.

  final double totalDistance; // 누적 러닝 거리 (m)
  final int totalRunSeconds; // 누적 러닝 시간 (초)
  final int totalMovingSeconds; // 누적 "움직인" 시간 (초) - 경험치 기준
  final int totalSteps; // 누적 걸음 수 - 골드 기준
  final int totalExp; // 지금까지 받은 경험치를 전부 합한 값 - 레벨 랭킹 기준

  const UserModel({
    required this.nickname,
    required this.level,
    required this.exp,
    required this.gold,
    required this.ownedSetIds,
    required this.equippedSetId,
    required this.totalDistance,
    required this.totalRunSeconds,
    required this.totalMovingSeconds,
    required this.totalSteps,
    required this.totalExp,
  });

  // 새로 가입한 유저의 기본값 - 장비 없이 맨몸으로 시작합니다.
  factory UserModel.initial(String nickname) {
    return UserModel(
      nickname: nickname,
      level: 1,
      exp: 0,
      gold: 0,
      ownedSetIds: const [],
      equippedSetId: null,
      totalDistance: 0,
      totalRunSeconds: 0,
      totalMovingSeconds: 0,
      totalSteps: 0,
      totalExp: 0,
    );
  }

  bool owns(String setId) => ownedSetIds.contains(setId);

  // Firestore는 숫자를 int/double 구분 없이 줄 수 있어서 num으로 받은 뒤 변환합니다.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      nickname: map['nickname'] ?? '이름없음',
      level: (map['level'] as num?)?.toInt() ?? 1,
      exp: (map['exp'] as num?)?.toInt() ?? 0,
      gold: (map['gold'] as num?)?.toInt() ?? 0,
      // 장비를 붙이기 전에 만든 문서에는 이 필드가 없어서 빈 목록으로 읽힙니다.
      ownedSetIds:
          (map['ownedSetIds'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      equippedSetId: map['equippedSetId'] as String?,
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0,
      totalRunSeconds: (map['totalRunSeconds'] as num?)?.toInt() ?? 0,
      totalMovingSeconds: (map['totalMovingSeconds'] as num?)?.toInt() ?? 0,
      totalSteps: (map['totalSteps'] as num?)?.toInt() ?? 0,
      // 랭킹을 붙이기 전에 만든 문서에는 없습니다. 그럴 땐 레벨과 경험치로 되짚어 구합니다.
      totalExp:
          (map['totalExp'] as num?)?.toInt() ??
          RunRules.totalExpFor(
            (map['level'] as num?)?.toInt() ?? 1,
            (map['exp'] as num?)?.toInt() ?? 0,
          ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'level': level,
      'exp': exp,
      'gold': gold,
      'ownedSetIds': ownedSetIds,
      'equippedSetId': equippedSetId,
      'totalDistance': totalDistance,
      'totalRunSeconds': totalRunSeconds,
      'totalMovingSeconds': totalMovingSeconds,
      'totalSteps': totalSteps,
      'totalExp': totalExp,
    };
  }
}
