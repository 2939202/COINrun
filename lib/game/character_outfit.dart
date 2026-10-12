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
//
// 강아지(허스키, 리트리버)도 고를 수 있는 캐릭터입니다. 모델 파일이 따로 있고
// (assets/models/dog_*.glb) 옷을 입지 않습니다. 대신 간식을 먹은 만큼 단계가 올라
// 그림체가 바뀝니다. (game/pet_catalog.dart) 뷰어에는 'dog:husky:2'처럼 넘깁니다.
// ============================================================

enum CharacterLook {
  female('female', '여자'),
  male('male', '남자'),
  husky('husky', '허스키'),
  golden('golden', '리트리버');

  final String id; // Firestore에 저장되는 값
  final String label;

  const CharacterLook(this.id, this.label);

  bool get isDog => this == husky || this == golden;

  static const List<CharacterLook> humans = [female, male];
  static const List<CharacterLook> dogs = [husky, golden];

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
  // setId가 null이면 기본 옷입니다.
  // 강아지는 옷이 없어서 강아지 그림 하나입니다.
  static String iconFor(CharacterLook look, String? setId) => look.isDog
      ? 'assets/icons/dog_${look.id}.png'
      : 'assets/icons/outfit_${look.id}_${setId ?? 'basic'}.png';

  // 플레이어 카드의 큰 전신 그림. 3D를 크게(약 690px) 찍어 둔 그림입니다.
  // 강아지는 따로 큰 그림이 없어서 강아지 그림을 씁니다.
  static String cardFor(CharacterLook look, String? setId) {
    if (look.isDog) return iconFor(look, null);
    final String outfit = clothesForSet.containsKey(setId) ? setId! : 'basic';
    return 'assets/icons/card_${look.id}_$outfit.png';
  }

  // 홈 "내 캐릭터" 카드의 얼굴 그림. 3D 모델로 찍어 둔 그림입니다. (assets/icons/)
  // 홈은 자주 열려서 3D(웹뷰)를 띄우지 않고 그림을 씁니다. 모르는 세트면 기본 옷입니다.
  static String faceFor(CharacterLook look, String? setId) {
    if (look.isDog) return iconFor(look, null);
    final String outfit = clothesForSet.containsKey(setId) ? setId! : 'basic';
    return 'assets/icons/face_${look.id}_$outfit.png';
  }

  // 이 모습과 장비로 켜야 할 파츠. 모르는 세트면 장비 없음으로 봅니다.
  // 강아지는 파츠 대신 'dog:종류:단계' 하나입니다.
  static List<String> partsFor(
    CharacterLook look,
    String? setId, {
    int dogStage = 1,
  }) {
    if (look.isDog) return ['dog:${look.id}:$dogStage'];
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
