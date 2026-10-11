import 'package:contact/game/equipment_catalog.dart';
import 'package:contact/game/equipment_rules.dart';
import 'package:contact/game/run_rules.dart';
import 'package:contact/models/run_record.dart';
import 'package:contact/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({
  int level = 1,
  int gold = 0,
  List<String> owned = const [],
  String? equipped,
}) => UserModel(
  nickname: '테스터',
  isGuest: false,
  trashEnabled: false,
  level: level,
  exp: 0,
  gold: gold,
  ownedSetIds: owned,
  equippedSetId: equipped,
  totalExp: 0,
  totalDistance: 0,
  totalRunSeconds: 0,
  totalMovingSeconds: 0,
  totalSteps: 0,
);

RunRecord _record({Duration movingTime = Duration.zero, int steps = 0}) =>
    RunRecord(
      elapsed: movingTime,
      movingTime: movingTime,
      distanceMeters: 0,
      steps: steps,
      stepsEstimated: false,
    );

void main() {
  group('구매 판정', () {
    test('골드와 레벨이 충분하면 살 수 있음', () {
      expect(
        EquipmentRules.checkPurchase(
          _user(level: 1, gold: 500),
          EquipmentCatalog.novice,
        ),
        PurchaseCheck.ok,
      );
    });

    test('레벨이 모자라면 골드가 넉넉해도 못 삼', () {
      expect(
        EquipmentRules.checkPurchase(
          _user(level: 4, gold: 999999),
          EquipmentCatalog.adept,
        ),
        PurchaseCheck.lockedByLevel,
      );
    });

    test('가격보다 1골드 모자라면 못 삼', () {
      expect(
        EquipmentRules.checkPurchase(
          _user(level: 1, gold: 499),
          EquipmentCatalog.novice,
        ),
        PurchaseCheck.notEnoughGold,
      );
    });

    test('이미 가진 세트는 다시 못 삼 (골드가 넉넉해도)', () {
      expect(
        EquipmentRules.checkPurchase(
          _user(level: 1, gold: 999999, owned: ['novice']),
          EquipmentCatalog.novice,
        ),
        PurchaseCheck.alreadyOwned,
      );
    });
  });

  group('장착 상태 읽기', () {
    test('맨몸이면 장비가 null', () {
      expect(EquipmentRules.equippedSet(_user()), isNull);
      expect(EquipmentRules.equippedSetName(_user()), '맨몸');
    });

    test('저장된 id가 목록에 없으면 맨몸으로 봄 (앱이 죽지 않도록)', () {
      final user = _user(equipped: '삭제된_세트');
      expect(EquipmentRules.equippedSet(user), isNull);
      expect(EquipmentRules.equippedSetName(user), '맨몸');
    });

    test('입은 세트를 찾아냄', () {
      final user = _user(owned: ['adept'], equipped: 'adept');
      expect(EquipmentRules.equippedSet(user), EquipmentCatalog.adept);
      expect(EquipmentRules.equippedSetName(user), '가죽옷');
    });
  });

  group('보상 보너스', () {
    test('맨몸이면 보너스 없이 그대로', () {
      final run = _record(movingTime: const Duration(minutes: 10), steps: 6000);
      expect(RunRules.expFor(run), 100);
      expect(RunRules.goldFor(run), 600);
    });

    test('초급 세트는 골드 +3%, 경험치 +3%', () {
      final run = _record(movingTime: const Duration(minutes: 10), steps: 6000);
      expect(RunRules.goldFor(run, gear: EquipmentCatalog.novice), 618);
      expect(RunRules.expFor(run, gear: EquipmentCatalog.novice), 103);
    });

    test('고급 세트는 골드 +15%, 경험치 +15%', () {
      final run = _record(movingTime: const Duration(minutes: 10), steps: 6000);
      expect(RunRules.goldFor(run, gear: EquipmentCatalog.master), 690);
      expect(RunRules.expFor(run, gear: EquipmentCatalog.master), 115);
    });

    test('소수점은 버림 (10골드 +3% -> 10골드)', () {
      expect(EquipmentRules.applyGoldBonus(10, EquipmentCatalog.novice), 10);
      expect(EquipmentRules.applyGoldBonus(100, EquipmentCatalog.novice), 103);
    });

    test('0은 보너스를 붙여도 0', () {
      expect(EquipmentRules.applyGoldBonus(0, EquipmentCatalog.master), 0);
      expect(EquipmentRules.applyExpBonus(0, EquipmentCatalog.master), 0);
    });
  });

  group('세트 목록', () {
    test('가격이 싼 것부터 정렬되어 있고 요구 레벨도 같이 올라감', () {
      final all = EquipmentCatalog.all;
      for (int i = 1; i < all.length; i++) {
        expect(all[i].price, greaterThan(all[i - 1].price));
        expect(
          all[i].requiredLevel,
          greaterThanOrEqualTo(all[i - 1].requiredLevel),
        );
        expect(all[i].power, greaterThan(all[i - 1].power));
      }
    });

    test('없는 id를 찾으면 null', () {
      expect(EquipmentCatalog.byId('없음'), isNull);
      expect(EquipmentCatalog.byId(null), isNull);
    });
  });

  group('UserModel 저장/읽기', () {
    test('장비를 붙이기 전에 만든 문서도 맨몸으로 읽힘', () {
      final user = UserModel.fromMap({'nickname': '옛유저', 'gold': 100});
      expect(user.ownedSetIds, isEmpty);
      expect(user.equippedSetId, isNull);
    });

    test('저장한 값을 그대로 다시 읽어옴', () {
      final user = _user(owned: ['novice', 'adept'], equipped: 'adept');
      final restored = UserModel.fromMap(user.toMap());
      expect(restored.ownedSetIds, ['novice', 'adept']);
      expect(restored.equippedSetId, 'adept');
    });
  });
}
