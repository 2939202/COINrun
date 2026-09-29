// ============================================================
// 주간/월간 요약을 담을 칸의 이름을 정합니다.
//
// [왜 요약을 따로 쌓나]
//   "이번 주에 얼마나 뛰었지"를 보려고 러닝 기록 60개를 매번 뒤질 필요가 없습니다.
//   러닝을 저장할 때 이번 주 칸과 이번 달 칸에 더해두면, 나중에 문서 하나만 읽으면 됩니다.
//
//   요약 한 칸은 숫자 몇 개라 150바이트쯤입니다. 10년치를 쌓아도 80KB로,
//   러닝 기록 12개 값도 안 됩니다. 그래서 요약은 지우지 않고 계속 둡니다.
//   상세 기록은 60개까지만 두고 밀어내도, "작년 3월에 42km 뛰었다"는 영원히 남습니다.
//
// [주 번호를 쓰지 않는 이유]
//   ISO 주 번호는 연말연시에 "12월 31일이 내년 1주차"가 되는 등 헷갈리는 구석이 많습니다.
//   그래서 그 주 월요일 날짜를 그대로 이름으로 씁니다. 계산이 단순하고 헷갈릴 일이 없습니다.
//     주간: w2026-09-28  (2026년 9월 28일 월요일이 시작인 주)
//     월간: m2026-09
// ============================================================
class StatsPeriod {
  StatsPeriod._();

  // 그 날이 속한 주의 월요일 0시
  static DateTime weekStart(DateTime time) {
    final DateTime day = DateTime(time.year, time.month, time.day);
    // DateTime.weekday는 월요일이 1, 일요일이 7입니다.
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static DateTime monthStart(DateTime time) => DateTime(time.year, time.month);

  static String weekKey(DateTime time) {
    final DateTime start = weekStart(time);
    return 'w${_date(start)}';
  }

  static String monthKey(DateTime time) => 'm${time.year}-${_two(time.month)}';

  static String _date(DateTime time) =>
      '${time.year}-${_two(time.month)}-${_two(time.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
