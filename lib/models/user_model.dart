class UserModel {
  final String nickname;
  final int level;
  final int gold;
  final String equipment;
  final int myRank;

  UserModel({
    required this.nickname,
    required this.level,
    required this.gold,
    required this.equipment,
    required this.myRank,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      nickname: map['nickname'] ?? '이름없음',
      level: map['level'] ?? 1,
      gold: map['gold'] ?? 0,
      equipment: map['equipment'] ?? '착용 무구 없음',
      myRank: map['myRank'] ?? 0,
    );
  }
}