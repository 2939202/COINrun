import '../models/equipment_set.dart';
import '../models/user_model.dart';
import 'equipment_catalog.dart';

// enum은 구조체 느낌인데, 데이터 대신 기능을 담음
enum PurchaseCheck {
  ok,
  alreadyOwned,
  lockedByLevel,
  notEnoughGold;

  // 현재 상태(this)가 구매 가능한 정상 상태와 동일한지(== PurchaseCheck.ok) 판별한 뒤,
  //그 참과 거짓의 결과를(bool) 게터(get)를 통해 isOk라는 속성 값으로 반환
  bool get isOk => this == PurchaseCheck.ok;

  // 화면과 오류 메시지에 그대로 쓰는 문구, break문이 딱히 필요가 없다
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
  //클래스도 enum처럼 묶는데 열거는 안함
  EquipmentRules._(); //다른 파일에서 적용이 되지 않게 ._()를 선언해서 메모리를 아낌

  // 맨몸일 때 화면에 보여주는 이름, static인 이유 : 안쓰면 바 네임이 동적으로 쓸 때마다 저장됨
  static const String bareName = '맨몸';

  //EquipmentSet장비가 "(유저가 )입고 있는 장비"가 없을 수 있음을 인지하고
  static EquipmentSet? equippedSet(UserModel user) => //(타입?의 의미 널 값 허용)
      EquipmentCatalog.byId(user.equippedSetId);
  //장비창고카탈로그로 가서 장비의 식별 번호(user.equippedSetId)의 데이터를 반환함

  static String equippedSetName(
    UserModel user,
  ) => //착용 장비 이름을 문자열로 반환하는 공용 메서드 정의
      equippedSet(user)?.name ?? bareName;
  //유저의 입은 장비 찾는데 널이 아니면 .name 널이면 맨몸
  static PurchaseCheck checkPurchase(UserModel user, EquipmentSet set) {
    //사용자와 장비 비교
    if (user.owns(set.id)) return PurchaseCheck.alreadyOwned;
    //이미 소유중인지
    if (user.level < set.requiredLevel) return PurchaseCheck.lockedByLevel;
    //레벨을 충족하는지
    if (user.gold < set.price) return PurchaseCheck.notEnoughGold;
    //골드가 충분한지
    return PurchaseCheck.ok;
    //아니면 살 수 있는지
  }

  // 보너스를 붙인 값. 장비가 없으면(gear == null) 원래 값 그대로입니다.
  // 소수점은 버립니다. (보너스 3%인데 골드 10 -> 10.3 -> 10)
  static int applyGoldBonus(int gold, EquipmentSet? gear) =>
      gear == null ? gold : gold * (100 + gear.power) ~/ 100;

  static int applyExpBonus(int exp, EquipmentSet? gear) =>
      gear == null ? exp : exp * (100 + gear.stamina) ~/ 100;
}
