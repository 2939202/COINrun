// ============================================================
// 명예 레벨 - 사설 코스를 만든 사람이 받는 기여도
//
// 코스를 하나라도 만들면 1, 그 뒤로는 내 코스들이 받은 하트를 모두 더해 올라갑니다.
//   Lv.1 코스 1개 이상  ·  Lv.2 하트 5  ·  Lv.3 하트 15  ·  Lv.4 하트 40  ·  Lv.5 하트 100
//
// 남이 내 코스를 몇 번 달렸는지는 세지 않습니다. 남의 러닝 기록은 본인만 읽을 수
// 있게 잠가 두었기 때문입니다. 하트는 코스 문서에 모여 있어서 셀 수 있습니다.
// ============================================================
class HonorLevel {
  static const List<int> heartsFor = [0, 5, 15, 40, 100]; // Lv.1 ~ Lv.5

  final int courses;
  final int hearts;

  const HonorLevel({required this.courses, required this.hearts});

  int get level {
    if (courses <= 0) return 0;
    int lv = 1;
    for (int i = 0; i < heartsFor.length; i++) {
      if (hearts >= heartsFor[i]) lv = i + 1;
    }
    return lv;
  }

  // 다음 레벨까지 남은 하트. 최고 레벨이거나 코스가 없으면 null
  int? get heartsToNext {
    final int lv = level;
    if (lv == 0 || lv >= heartsFor.length) return null;
    return heartsFor[lv] - hearts;
  }
}
