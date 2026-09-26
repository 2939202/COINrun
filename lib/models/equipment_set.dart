// ============================================================
// 장비 세트 한 벌
//
// 이 앱의 장비는 투구/갑옷/무기를 따로 사는 방식이 아니라,
// "초급 모험가 세트"처럼 한 벌을 통째로 사서 통째로 입는 방식입니다.
// 그래서 유저가 입고 있는 장비는 항상 세트 하나(또는 맨몸)뿐입니다.
//
// 능력치 3종(힘/체력/속도)은 홈/캐릭터 화면에 보여주는 값이면서, 실제 보상에도 영향을 줍니다.
// 어떻게 영향을 주는지는 game/equipment_rules.dart를 보세요.
// ============================================================
class EquipmentSet {
  final String id; // Firestore에 저장되는 값. 한 번 정하면 바꾸지 않습니다.
  final String name;
  final String description;
  final int price; // 골드
  final int requiredLevel; // 이 레벨이 되어야 살 수 있습니다.

  final int power; // 힘 - 골드 획득량을 이 수치(%)만큼 올려줍니다.
  final int stamina; // 체력 - 경험치 획득량을 이 수치(%)만큼 올려줍니다.
  final int speed; // 속도 - 아직 쓰는 곳이 없습니다. (나중에 사용할 자리)

  const EquipmentSet({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.requiredLevel,
    required this.power,
    required this.stamina,
    required this.speed,
  });
}
