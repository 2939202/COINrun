// ============================================================
// 3D 캐릭터에 무엇을 보이게 할지
//
// 캐릭터 파일(assets/models/character.glb) 하나에 남녀 머리, 몸, 옷이 전부
// 같은 자리에 겹쳐 들어 있습니다. 파츠 이름으로 골라서 켜고, 나머지는 끕니다.
//
//            장비 없음                천옷(초급)       가죽옷(중급)       갑옷(고급)
//   남자     head ArmLeg basic        head ArmLeg      head ArmLeg        head armor
//                                     fabric           leather
//   여자     womanHEAD woman          womanHEAD ArmLeg womanHEAD ArmLeg   womanHEAD armor
//                                     fabric           leather
//
// 여자는 기본 옷(woman)만 따로 있고, 나머지 옷은 남자 것을 같이 입습니다.
// 갑옷에는 팔다리까지 들어 있어서 ArmLeg를 켜지 않습니다.
// 파츠 이름은 블렌더에서 붙인 이름 그대로입니다. 바꾸면 여기도 고쳐야 합니다.
// ============================================================

enum CharacterLook {
  female('female', '여자'),
  male('male', '남자');

  final String id; // Firestore에 저장되는 값
  final String label;

  const CharacterLook(this.id, this.label);

  // 아직 고르지 않았거나 모르는 값이면 null입니다. (처음 들어올 때 고르는 화면을 띄웁니다)
  static CharacterLook? tryParse(Object? id) {
    for (final look in values) {
      if (look.id == id) return look;
    }
    return null;
  }
}

class CharacterOutfit {
  CharacterOutfit._();

  // 장비 세트 id(game/equipment_catalog.dart) → 옷 파츠
  static const Map<String, String> clothesForSet = {
    'novice': 'fabric',
    'adept': 'leather',
    'master': 'armor',
  };

  // 파일 안의 파츠 전부. 뷰어는 이 목록에 없는 이름도 그냥 끕니다.
  static const List<String> allParts = [
    'head',
    'womanHEAD',
    'ArmLeg',
    'basic',
    'woman',
    'fabric',
    'leather',
    'armor',
  ];

  // 잡화점에 보이는 옷 아이콘. 3D 모델로 찍어 둔 그림입니다. (assets/icons/)
  static String iconFor(CharacterLook look, String setId) =>
      'assets/icons/outfit_${look.id}_$setId.png';

  // 이 모습과 장비로 켜야 할 파츠. 모르는 세트면 장비 없음으로 봅니다.
  static List<String> partsFor(CharacterLook look, String? setId) {
    final String head = look == CharacterLook.male ? 'head' : 'womanHEAD';
    final String? clothes = clothesForSet[setId];
    if (clothes == null) {
      return look == CharacterLook.male
          ? [head, 'ArmLeg', 'basic']
          : [head, 'woman'];
    }
    if (clothes == 'armor') return [head, 'armor'];
    return [head, 'ArmLeg', clothes];
  }
}
