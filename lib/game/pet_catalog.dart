// ============================================================
// 간식과 강아지 캐릭터의 단계
//
// 강아지(허스키, 리트리버)는 여자·남자와 같은 캐릭터지만 자라는 방식이 다릅니다.
// 옷 대신, 잡화점에서 산 간식을 먹은 개수만큼 3단계로 자랍니다.
// 단계마다 3D 뷰어의 그림체가 바뀝니다. (assets/viewer/index.html의 DOG_STAGES)
//   1단계: 큰 픽셀, 흑백   2단계: 중간 픽셀, 색이 반쯤   3단계: 사람과 같은 그림체
// 먹은 개수는 강아지마다 따로 셉니다. (users/{uid}.petFed)
// ============================================================
class Snack {
  final String id;
  final String name;
  final String description;
  final String asset;

  const Snack({
    required this.id,
    required this.name,
    required this.description,
    required this.asset,
  });
}

class PetCatalog {
  PetCatalog._();

  // 뼈다귀 비스킷이 든 종이봉투 그림
  static const Snack snack = Snack(
    id: 'snack',
    name: '간식',
    description: '강아지 캐릭터에게 주면 조금씩 자랍니다',
    asset: 'assets/icons/snack.png',
  );

  // 간식 하나 값. 살 때 끌어서 개수를 고르고(1~maxPerPurchase), 개수만큼 냅니다.
  static const int snackPrice = 80;
  static const int maxPerPurchase = 50;

  static const int maxStage = 3;

  // 이만큼 간식을 먹으면 그 단계가 됩니다. [2단계, 3단계]
  static const List<int> stageAt = [4, 12];

  static int stageFor(int fed) {
    if (fed >= stageAt[1]) return 3;
    if (fed >= stageAt[0]) return 2;
    return 1;
  }

  // 다음 단계까지 남은 간식. 다 자랐으면 null입니다.
  static int? snacksToNext(int fed) {
    final int stage = stageFor(fed);
    if (stage >= maxStage) return null;
    return stageAt[stage - 1] - fed;
  }
}
