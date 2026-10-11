import 'dart:io';

import 'package:contact/game/character_outfit.dart';
import 'package:contact/game/equipment_catalog.dart';
import 'package:contact/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterOutfit.partsFor', () {
    test('장비가 없으면 기본 옷을 입습니다', () {
      expect(CharacterOutfit.partsFor(CharacterLook.male, null), [
        'head',
        'ArmLeg',
        'basic',
      ]);
      expect(CharacterOutfit.partsFor(CharacterLook.female, null), [
        'womanHEAD',
        'woman',
      ]);
    });

    test('천옷과 가죽옷은 팔다리를 같이 켭니다', () {
      expect(CharacterOutfit.partsFor(CharacterLook.male, 'novice'), [
        'head',
        'ArmLeg',
        'fabric',
      ]);
      expect(CharacterOutfit.partsFor(CharacterLook.female, 'adept'), [
        'womanHEAD',
        'ArmLeg',
        'leather',
      ]);
    });

    test('갑옷은 머리와 갑옷만 켭니다', () {
      expect(CharacterOutfit.partsFor(CharacterLook.male, 'master'), [
        'head',
        'armor',
      ]);
      expect(CharacterOutfit.partsFor(CharacterLook.female, 'master'), [
        'womanHEAD',
        'armor',
      ]);
    });

    test('모르는 세트는 장비 없음으로 봅니다', () {
      expect(
        CharacterOutfit.partsFor(CharacterLook.male, 'unknown'),
        CharacterOutfit.partsFor(CharacterLook.male, null),
      );
    });

    test('모든 세트에 옷이 있고, 켜는 파츠는 전부 파일 안에 있습니다', () {
      for (final set in EquipmentCatalog.all) {
        expect(CharacterOutfit.clothesForSet, contains(set.id));
      }
      for (final look in CharacterLook.values) {
        for (final setId in [null, ...EquipmentCatalog.all.map((s) => s.id)]) {
          for (final part in CharacterOutfit.partsFor(look, setId)) {
            expect(CharacterOutfit.allParts, contains(part));
          }
        }
      }
    });
  });

  test('모든 옷에 남녀 아이콘이 있습니다', () {
    for (final look in CharacterLook.values) {
      for (final set in EquipmentCatalog.all) {
        final String path = CharacterOutfit.iconFor(look, set.id);
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  group('UserModel.look', () {
    test('저장한 모습을 그대로 읽습니다', () {
      final map = UserModel.initial('a', isGuest: false).toMap()
        ..['look'] = 'male';
      final user = UserModel.fromMap(map);
      expect(user.look, CharacterLook.male);
      expect(user.toMap()['look'], 'male');
    });

    test('값이 없거나 모르는 값이면 아직 안 고른 것(null)입니다', () {
      expect(UserModel.fromMap({}).look, isNull);
      expect(UserModel.fromMap({'look': 'cat'}).look, isNull);
      expect(
        UserModel.initial('a', isGuest: false).toMap(),
        isNot(contains('look')),
      );
    });
  });
}
