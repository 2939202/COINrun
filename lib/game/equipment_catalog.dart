import '../models/equipment_set.dart';

// ============================================================
// 상점에서 파는 장비 세트 목록
//
// 지금은 코드 안에 적어두었습니다. 나중에 세트를 자주 추가하게 되면
// Firestore로 옮기면 되는데, 그때도 화면은 이 파일만 바라보게 해두면
// 옮기는 작업이 이 파일 안에서 끝납니다.
//
// [가격을 이렇게 정한 이유]
//   보상 규칙이 10걸음당 1골드라서, 5km 러닝 한 번이 대략 600골드입니다.
//     - 초급  500골드: 첫 러닝 한 번이면 살 수 있습니다.
//     - 중급 3000골드: 누적 25km 쯤. 요구 레벨 5는 움직인 시간 100분 쯤이라 비슷하게 도착합니다.
//     - 고급 12000골드: 누적 100km 쯤. 요구 레벨 10도 비슷한 시점입니다.
//   골드와 레벨 중 한쪽만 먼저 차면 기다려야 하도록 일부러 비슷하게 맞췄습니다.
// ============================================================
class EquipmentCatalog {
  EquipmentCatalog._();

  static const EquipmentSet novice = EquipmentSet(
    id: 'novice',
    name: '초급 모험가 세트',
    description: '처음 길을 나서는 사람이 갖추는 기본 차림.',
    price: 500,
    requiredLevel: 1,
    power: 3,
    stamina: 3,
    speed: 2,
  );

  static const EquipmentSet adept = EquipmentSet(
    id: 'adept',
    name: '중급 모험가 세트',
    description: '먼 길을 여러 번 다녀온 사람이 갖추는 차림.',
    price: 3000,
    requiredLevel: 5,
    power: 8,
    stamina: 8,
    speed: 5,
  );

  static const EquipmentSet master = EquipmentSet(
    id: 'master',
    name: '고급 모험가 세트',
    description: '오래 달려온 사람만이 갖출 수 있는 차림.',
    price: 12000,
    requiredLevel: 10,
    power: 15,
    stamina: 15,
    speed: 10,
  );

  // 상점에 보여주는 순서 (싼 것부터)
  static const List<EquipmentSet> all = [novice, adept, master];

  // 저장된 id로 세트를 찾습니다. 없는 id면 null입니다.
  // (예전 버전에서 저장한 id가 남아 있어도 앱이 죽지 않도록 null을 돌려줍니다)
  static EquipmentSet? byId(String? id) {
    if (id == null) return null;
    for (final set in all) {
      if (set.id == id) return set;
    }
    return null;
  }
}
