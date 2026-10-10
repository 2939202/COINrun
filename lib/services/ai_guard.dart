// ============================================================
// AI 문장 검사 - 숫자 충실성
//
// LLM은 그럴듯한 숫자를 지어낼 수 있습니다. 그래서 AI가 쓴 문장 속 숫자가
// 우리가 보낸 사실에서 나온 것인지 확인하고, 아니면 그 문장을 버립니다.
//
// [허용하는 숫자]
//   1. 보낸 글에 들어 있던 숫자
//   2. 그 숫자 둘의 차이  (예: 12km와 4km -> "8km 줄었습니다")
//   3. "%"가 붙은 숫자만: 그 숫자 둘의 비율 (예: 10.4 / 12 -> "87%")
//   4. 0~7의 정수 (요일 수, "한 번 더" 같은 셈)
//   반올림 차이는 봐줍니다. (소수 첫째·둘째 자리, 정수)
//
// 비율을 아무 숫자에나 허용하면 숫자 수십 개의 모든 비율이 거의 모든 정수를 덮어서
// 검사가 의미 없어집니다. 그래서 비율은 "%"가 붙은 숫자에만 씁니다.
//
// 시간·페이스(6'38", 31:20)는 분과 초가 따로 숫자로 잡힙니다. 보낸 글에도
// 같은 꼴로 들어 있어서 그대로 맞춰집니다.
// ============================================================
class AiGuard {
  AiGuard._();

  static final RegExp _number = RegExp(r'\d+(?:\.\d+)?');
  static final RegExp _numberWithUnit = RegExp(r'(\d+(?:\.\d+)?)\s*(%?)');

  static List<double> numbersIn(String text) => [
    for (final m in _number.allMatches(text)) double.parse(m.group(0)!),
  ];

  // 보낸 글에서 허용할 숫자들을 만듭니다.
  static AllowedNumbers allowedFrom(String sentText) {
    final List<double> base = numbersIn(sentText).toSet().toList();
    final Set<double> plain = {
      ...base,
      for (int i = 0; i <= 7; i++) i.toDouble(),
    };
    final Set<double> percent = {...base};
    for (final a in base) {
      for (final b in base) {
        plain.add((a - b).abs());
        if (b != 0) percent.add(a / b * 100);
      }
    }
    return AllowedNumbers(plain.toList(), percent.toList());
  }

  // 문장 속 숫자가 전부 허용 목록에서 나왔는지
  static bool supported(String sentence, AllowedNumbers allowed) {
    for (final m in _numberWithUnit.allMatches(sentence)) {
      final double n = double.parse(m.group(1)!);
      final List<double> pool = m.group(2) == '%'
          ? allowed.percent
          : allowed.plain;
      if (!pool.any((v) => _close(n, v))) return false;
    }
    return true;
  }

  static bool _close(double n, double v) =>
      (n - v).abs() < 1e-9 ||
      (n - (v * 10).round() / 10).abs() < 1e-9 ||
      (n - (v * 100).round() / 100).abs() < 1e-9 ||
      (n - v.round()).abs() < 1e-9 ||
      (n - v.floor()).abs() < 1e-9;
}

class AllowedNumbers {
  final List<double> plain; // 보낸 숫자, 그 차이, 0~7
  final List<double> percent; // 보낸 숫자, 그 비율(%)

  const AllowedNumbers(this.plain, this.percent);
}
