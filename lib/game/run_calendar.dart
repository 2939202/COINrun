import '../models/run_log.dart';
import 'stats_period.dart';

// ============================================================
// AI 평가 달력
//
// 이번 달을 월요일부터 시작하는 7칸 x 몇 줄로 펼치고, 날마다 달린 거리를 셉니다.
// 앞뒤로 비는 칸은 지난달/다음 달 날짜로 채웁니다.
//
// 어느 칸을 "이번 기간"으로 밝게 칠할지
//   주간 탭 - 오늘이 든 주의 7칸
//   월간 탭 - 이번 달 날짜 전부
// ============================================================
class RunCalendar {
  final DateTime today; // 날짜만 (시각 없음)
  final DateTime first; // 달력 첫 칸 (월요일)
  final int weeks; // 줄 수 (4~6)
  final Map<DateTime, double> kmByDay;

  RunCalendar._(this.today, this.first, this.weeks, this.kmByDay);

  // 이번 달 달력. runs는 [rangeOf]의 기간 안 기록이면 됩니다.
  factory RunCalendar.of(DateTime now, List<RunLog> runs) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final (DateTime start, DateTime end) = rangeOf(now);
    final int weeks = end.difference(start).inDays ~/ 7;

    final Map<DateTime, double> km = {};
    for (final run in runs) {
      final DateTime? at = run.createdAt?.toLocal();
      if (at == null) continue;
      final DateTime day = DateTime(at.year, at.month, at.day);
      km[day] = (km[day] ?? 0) + run.distanceMeters / 1000;
    }
    return RunCalendar._(today, start, weeks, km);
  }

  // 달력에 보이는 기간: 이번 달 1일이 든 주의 월요일 ~ 말일이 든 주의 다음 월요일(미포함)
  static (DateTime, DateTime) rangeOf(DateTime now) {
    final DateTime monthStart = DateTime(now.year, now.month);
    final DateTime monthLast = DateTime(now.year, now.month + 1, 0);
    final DateTime start = StatsPeriod.weekStart(monthStart);
    final DateTime lastWeek = StatsPeriod.weekStart(monthLast);
    return (start, DateTime(lastWeek.year, lastWeek.month, lastWeek.day + 7));
  }

  // 위에서부터 줄마다 7칸
  List<List<DateTime>> get rows => [
    for (int w = 0; w < weeks; w++)
      [
        for (int d = 0; d < 7; d++)
          DateTime(first.year, first.month, first.day + w * 7 + d),
      ],
  ];

  double kmOn(DateTime day) => kmByDay[day] ?? 0;

  bool isThisMonth(DateTime day) =>
      day.year == today.year && day.month == today.month;

  bool isThisWeek(DateTime day) =>
      StatsPeriod.weekStart(day) == StatsPeriod.weekStart(today);

  bool isFuture(DateTime day) => day.isAfter(today);

  // 게이지 눈금: 이 달 가장 많이 뛴 날을 가득으로. 너무 짧은 날이 가득 차 보이지
  // 않도록 최소 5km를 가득으로 봅니다.
  double get gaugeFullKm {
    double most = 5;
    for (final km in kmByDay.values) {
      if (km > most) most = km;
    }
    return most;
  }
}
