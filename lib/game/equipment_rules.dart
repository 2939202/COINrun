import '../models/equipment_set.dart';
import '../models/user_model.dart';
import 'equipment_catalog.dart';

// 세트를 살 수 있는지 확인한 결과
enum PurchaseCheck {
  ok,
  alreadyOwned,
  lockedByLevel,
  notEnoughGold;

  bool get isOk => this == PurchaseCheck.ok;

  // 화면과 오류 메시지에 그대로 쓰는 문구
  String message(EquipmentSet set) {
    switch (this) {
      case PurchaseCheck.ok:
        return '구매할 수 있습니다.';
      case PurchaseCheck.alreadyOwned:
        return '이미 가지고 있는 세트입니다.';
      case PurchaseCheck.lockedByLevel:
        return 'Lv.${set.requiredLevel}부터 살 수 있습니다.';
      case PurchaseCheck.notEnoughGold:
        return '골드가 모자랍니다. (${set.price} G 필요)';
    }
  }
}

// ============================================================
// 장비 규칙: 살 수 있는지 판정 + 장비가 보상에 주는 영향
// 장비 수치를 바꿀 때는 equipment_catalog.dart를, 계산 방식을 바꿀 때는 이 파일을 고칩니다.
//
//   - 힘(power)   -> 골드를 이 수치(%)만큼 더 받습니다.
//   - 체력(stamina) -> 경험치를 이 수치(%)만큼 더 받습니다.
//   - 속도(speed)  -> 아직 쓰는 곳이 없습니다.
// ============================================================
class EquipmentRules {
  EquipmentRules._();

  // 맨몸일 때 화면에 보여주는 이름
  static const String bareName = '맨몸';

  static EquipmentSet? equippedSet(UserModel user) =>
      EquipmentCatalog.byId(user.equippedSetId);

  static String equippedSetName(UserModel user) =>
      equippedSet(user)?.name ?? bareName;

  static PurchaseCheck checkPurchase(UserModel user, EquipmentSet set) {
    if (user.owns(set.id)) return PurchaseCheck.alreadyOwned;
    if (user.level < set.requiredLevel) return PurchaseCheck.lockedByLevel;
    if (user.gold < set.price) return PurchaseCheck.notEnoughGold;
    return PurchaseCheck.ok;
  }

  // 보너스를 붙인 값. 장비가 없으면(gear == null) 원래 값 그대로입니다.
  // 소수점은 버립니다. (보너스 3%인데 골드 10 -> 10.3 -> 10)
  static int applyGoldBonus(int gold, EquipmentSet? gear) =>
      gear == null ? gold : gold * (100 + gear.power) ~/ 100;

  static int applyExpBonus(int exp, EquipmentSet? gear) =>
      gear == null ? exp : exp * (100 + gear.stamina) ~/ 100;
}
