import 'dart:io';

import 'package:contact/game/character_outfit.dart';
import 'package:contact/game/pet_catalog.dart';
import 'package:contact/game/player_number.dart';
import 'package:contact/models/user_model.dart';
import 'package:contact/screens/player_card_screen.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user(Map<String, dynamic> extra) => UserModel.fromMap({
  ...UserModel.initial('a', isGuest: false).toMap(),
  ...extra,
});

void main() {
  group('보이는 옷 (visibleSetId)', () {
    test('따로 고르지 않았으면 능력치 옷을 보여줍니다', () {
      final user = _user({
        'ownedSetIds': ['novice'],
        'equippedSetId': 'novice',
      });
      expect(user.visibleSetId, 'novice');
    });

    test('기본 옷을 고르면 능력치 옷과 상관없이 기본 옷입니다', () {
      final user = _user({
        'ownedSetIds': ['master'],
        'equippedSetId': 'master',
        'outfitSetId': 'basic',
      });
      expect(user.visibleSetId, isNull);
      expect(user.equippedSetId, 'master');
    });

    test('보이는 옷과 능력치 옷을 다르게 입을 수 있습니다', () {
      final user = _user({
        'ownedSetIds': ['novice', 'master'],
        'equippedSetId': 'master',
        'outfitSetId': 'novice',
      });
      expect(user.visibleSetId, 'novice');
    });

    test('갖고 있지 않은 옷이 적혀 있으면 능력치 옷을 따릅니다', () {
      final user = _user({
        'ownedSetIds': ['novice'],
        'equippedSetId': 'novice',
        'outfitSetId': 'master',
      });
      expect(user.visibleSetId, 'novice');
    });
  });

  group('플레이어 카드', () {
    test('같은 uid면 같은 번호, 8자리를 4자리씩 띄웁니다', () {
      final String a = PlayerNumber.of('abcDEF123');
      expect(a, PlayerNumber.of('abcDEF123'));
      expect(a, matches(RegExp(r'^\d{4} \d{4}$')));
      expect(PlayerNumber.of('other'), isNot(a));
    });

    test('QR에는 계정을 가리키는 주소가 들어갑니다', () {
      expect(PlayerCardScreen.qrData('abc'), 'coinrun://app/player/abc');
    });
  });

  group('강아지와 간식', () {
    test('간식을 먹은 개수로 1~3단계가 됩니다', () {
      expect(PetCatalog.stageFor(0), 1);
      expect(PetCatalog.stageFor(PetCatalog.stageAt[0]), 2);
      expect(PetCatalog.stageFor(PetCatalog.stageAt[1]), 3);
      expect(PetCatalog.stageFor(999), 3);
    });

    test('다음 단계까지 남은 간식을 셉니다', () {
      expect(PetCatalog.snacksToNext(0), PetCatalog.stageAt[0]);
      expect(PetCatalog.snacksToNext(PetCatalog.stageAt[1]), isNull);
    });

    test('가진 간식과 강아지마다 먹은 개수를 읽습니다', () {
      final user = _user({
        'snacks': 3,
        'petFed': {'golden': 5},
      });
      expect(user.snacks, 3);
      expect(user.fedOf('golden'), 5);
      expect(user.fedOf('husky'), 0);
    });

    test('강아지 캐릭터는 옷 대신 단계로 뷰어에 넘깁니다', () {
      expect(
        CharacterOutfit.partsFor(CharacterLook.husky, 'master', dogStage: 2),
        ['dog:husky:2'],
      );
      final user = _user({
        'look': 'golden',
        'petFed': {'golden': PetCatalog.stageAt[1]},
      });
      expect(user.dogStage, 3);
      expect(user.parts(), ['dog:golden:3']);
      expect(_user({'look': 'male'}).dogStage, isNull);
    });

    test('간식 그림과 강아지 모델 파일이 있습니다', () {
      expect(File(PetCatalog.snack.asset).existsSync(), isTrue);
      for (final dog in CharacterLook.dogs) {
        expect(File('assets/models/dog_${dog.id}.glb').existsSync(), isTrue);
        expect(File(CharacterOutfit.iconFor(dog, null)).existsSync(), isTrue);
      }
    });
  });

  test('옷 그림 파일이 모두 있습니다', () {
    for (final look in CharacterLook.values) {
      for (final setId in [null, ...CharacterOutfit.clothesForSet.keys]) {
        final String path = CharacterOutfit.iconFor(look, setId);
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });
}
