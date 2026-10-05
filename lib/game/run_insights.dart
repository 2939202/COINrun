import '../models/run_stats.dart';
import 'stats_period.dart';

// ============================================================
// AI 평가 - 주간/월간 러닝 기록을 읽고 점수, 한 줄 평, 조언을 만듭니다.
//
// 서버 없이 폰 안에서 규칙으로 계산합니다. (외부로 기록을 보내지 않습니다)
// 화면과 떨어져 있어서 테스트할 수 있습니다.
//
// [점수 100점]
//   꾸준함 40점 - 지난 4주(4달) 중 뛴 주(달)가 몇 번인가
//   운동량 30점 - 지난 4주(4달) 평균 거리가 목표(주 10km / 달 40km)에 얼마나 닿았나
//   흐름   30점 - 이번 주(달)가 지난주(달)보다 늘었나
//
// [진행 중인 기간]
//   이번 주가 수요일이면 아직 3/7만 지났습니다. 그대로 지난주와 비교하면 항상 줄어든 것처럼
//   보여서, 지금 속도로 끝까지 가면 얼마가 될지(예상치)로 비교합니다.
// ============================================================
enum InsightRange {
  week('주간', '이번 주', '지난주', '주', 10),
  month('월간', '이번 달', '지난달', '달', 40);

  final String label;
  final String current;
  final String previous;
  final String unit;
  final double targetKm; // 이만큼 뛰면 운동량 만점

  const InsightRange(
    this.label,
    this.current,
    this.previous,
    this.unit,
    this.targetKm,
  );

  bool get isWeek => this == InsightRange.week;
}

// 한 기간의 숫자. 뛰지 않은 기간은 칸이 없어서 0으로 채웁니다.
class PeriodSummary {
  final DateTime start;
  final int runs;
  final double km;
  final int movingSeconds;

  const PeriodSummary({
    required this.start,
    required this.runs,
    required this.km,
    required this.movingSeconds,
  });

  factory PeriodSummary.of(DateTime start, RunStats? stats) => PeriodSummary(
    start: start,
    runs: stats?.runs ?? 0,
    km: stats?.distanceKm ?? 0,
    movingSeconds: stats?.movingSeconds ?? 0,
  );

  bool get active => runs > 0;

  // 1km에 몇 분 걸렸는지. 거리가 너무 짧으면 믿을 수 없어서 null.
  double? get paceMinPerKm => km < 0.3 ? null : movingSeconds / 60 / km;

  double get averageKm => runs == 0 ? 0 : km / runs;
}

enum InsightTone { good, warn, info }

class InsightComment {
  final InsightTone tone;
  final String text;

  const InsightComment(this.tone, this.text);
}

class InsightReport {
  final InsightRange range;
  final List<PeriodSummary> periods; // 오래된 것부터, 마지막이 이번 주(달)
  final double progress; // 이번 주(달)가 얼마나 지났나 0~1
  final int score;
  final int consistencyScore;
  final int volumeScore;
  final int trendScore;
  final String headline;
  final List<InsightComment> comments;

  const InsightReport({
    required this.range,
    required this.periods,
    required this.progress,
    required this.score,
    required this.consistencyScore,
    required this.volumeScore,
    required this.trendScore,
    required this.headline,
    required this.comments,
  });

  PeriodSummary get current => periods.last;
  PeriodSummary get previous => periods[periods.length - 2];

  // 지금 속도로 이번 주(달)를 마치면 몇 km가 될지
  double get projectedKm =>
      progress <= 0 ? current.km : current.km / progress.clamp(0.15, 1.0);

  bool get hasAnyRun => periods.any((period) => period.active);
}

class RunInsights {
  RunInsights._();

  // 분석에 쓰는 기간 수 (이번 주 포함). 꾸준함은 그중 지난 4개로 봅니다.
  static const int periodCount = 6;
  static const int lookback = 4;

  // 읽어와야 할 요약 칸의 이름들 (오래된 것부터)
  static List<String> keysFor(InsightRange range, DateTime now) => [
    for (final start in startsFor(range, now))
      range.isWeek ? StatsPeriod.weekKey(start) : StatsPeriod.monthKey(start),
  ];

  static List<DateTime> startsFor(InsightRange range, DateTime now) {
    if (range.isWeek) {
      final DateTime thisWeek = StatsPeriod.weekStart(now);
      return [
        for (int back = periodCount - 1; back >= 0; back--)
          DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * back),
      ];
    }
    return [
      for (int back = periodCount - 1; back >= 0; back--)
        DateTime(now.year, now.month - back),
    ];
  }

  // 이번 주(달)가 얼마나 지났나. 월요일 정오면 주간은 약 0.07
  static double progressOf(InsightRange range, DateTime now) {
    final DateTime start = range.isWeek
        ? StatsPeriod.weekStart(now)
        : StatsPeriod.monthStart(now);
    final DateTime end = range.isWeek
        ? DateTime(start.year, start.month, start.day + 7)
        : DateTime(start.year, start.month + 1);
    final double total = end.difference(start).inSeconds.toDouble();
    return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
  }

  static InsightReport analyze({
    required InsightRange range,
    required Map<String, RunStats> statsByKey,
    required DateTime now,
  }) {
    final List<DateTime> starts = startsFor(range, now);
    final List<String> keys = keysFor(range, now);
    final List<PeriodSummary> periods = [
      for (int i = 0; i < starts.length; i++)
        PeriodSummary.of(starts[i], statsByKey[keys[i]]),
    ];
    final double progress = progressOf(range, now);

    final PeriodSummary current = periods.last;
    final PeriodSummary previous = periods[periods.length - 2];
    // 다 끝난 기간 중 최근 4개 (이번 주 제외)
    final List<PeriodSummary> past = periods.sublist(
      periods.length - 1 - lookback,
      periods.length - 1,
    );

    // --- 점수 ---
    final int activePast = past.where((period) => period.active).length;
    final int consistencyScore = (40 * activePast / lookback).round();

    final double pastAverageKm =
        past.fold<double>(0, (sum, period) => sum + period.km) / lookback;
    final int volumeScore = (30 * (pastAverageKm / range.targetKm).clamp(0, 1))
        .round();

    final double projected = progress <= 0
        ? current.km
        : current.km / progress.clamp(0.15, 1.0);
    final int trendScore = _trendScore(projected, previous.km);

    final int score = consistencyScore + volumeScore + trendScore;

    // --- 한 줄 평과 조언 ---
    final bool hasAnyRun = periods.any((period) => period.active);
    final String headline = _headline(
      range,
      hasAnyRun: hasAnyRun,
      score: score,
      current: current,
      projected: projected,
      previous: previous,
    );
    final List<InsightComment> comments = hasAnyRun
        ? _comments(
            range,
            periods: periods,
            past: past,
            current: current,
            previous: previous,
            projected: projected,
            progress: progress,
            activePast: activePast,
          )
        : [
            InsightComment(
              InsightTone.info,
              '첫 러닝을 마치면 ${range.label} 분석이 시작돼요. 10분만 걸어도 기록이 남아요.',
            ),
          ];

    return InsightReport(
      range: range,
      periods: periods,
      progress: progress,
      score: score,
      consistencyScore: consistencyScore,
      volumeScore: volumeScore,
      trendScore: trendScore,
      headline: headline,
      comments: comments,
    );
  }

  // 지난주와 같으면 15점, 1.5배 이상이면 만점, 절반 이하면 0점
  static int _trendScore(double projected, double previousKm) {
    if (previousKm <= 0) return projected > 0 ? 30 : 0;
    final double ratio = projected / previousKm;
    return (30 * ((ratio - 0.5) / 1.0).clamp(0, 1)).round();
  }

  static String _headline(
    InsightRange range, {
    required bool hasAnyRun,
    required int score,
    required PeriodSummary current,
    required double projected,
    required PeriodSummary previous,
  }) {
    if (!hasAnyRun) return '아직 분석할 기록이 없어요';
    if (!current.active) return '${range.current}는 아직 출발 전이에요';
    if (previous.km > 0 && projected >= previous.km * 1.1) {
      return '${range.previous}보다 페이스가 좋아요';
    }
    if (previous.km > 0 && projected < previous.km * 0.7) {
      return '${range.previous}보다 조금 느슨해졌어요';
    }
    if (score >= 75) return '꾸준함이 몸에 붙었어요';
    if (score >= 55) return '좋은 흐름을 타고 있어요';
    return '한 걸음씩 쌓이는 중이에요';
  }

  static List<InsightComment> _comments(
    InsightRange range, {
    required List<PeriodSummary> periods,
    required List<PeriodSummary> past,
    required PeriodSummary current,
    required PeriodSummary previous,
    required double projected,
    required double progress,
    required int activePast,
  }) {
    final List<InsightComment> out = [];
    final String unit = range.unit;

    // 1. 꾸준함
    if (activePast == lookback) {
      out.add(
        InsightComment(
          InsightTone.good,
          '$lookback$unit 연속으로 뛰었어요. 습관이 되는 가장 어려운 구간을 넘었어요.',
        ),
      );
    } else if (activePast <= 1) {
      out.add(
        InsightComment(
          InsightTone.warn,
          '지난 $lookback$unit 중 $activePast번만 뛰었어요. '
          '${range.isWeek ? "주 2번, 20분" : "주 1번"}부터 다시 시작해 보세요.',
        ),
      );
    }

    // 2. 이번 주(달) 진행 상황
    if (!current.active) {
      out.add(
        InsightComment(
          InsightTone.info,
          '${range.current}는 아직 기록이 없어요. 짧게라도 한 번 뛰면 흐름이 이어져요.',
        ),
      );
    } else if (previous.km > 0) {
      final int percent = ((projected / previous.km - 1) * 100).round();
      if (percent >= 30) {
        // 10% 규칙: 운동량을 갑자기 크게 늘리면 다치기 쉽습니다.
        out.add(
          InsightComment(
            InsightTone.warn,
            '지금 속도면 ${range.previous}보다 $percent% 더 뛰게 돼요. '
            '갑자기 많이 늘리면 무릎과 발목에 무리가 가요. 한 번은 쉬어가는 날로 두세요.',
          ),
        );
      } else if (percent >= 5) {
        out.add(
          InsightComment(
            InsightTone.good,
            '지금 속도면 ${range.previous}보다 $percent% 많이 뛰어요. 늘리는 폭도 딱 좋아요.',
          ),
        );
      } else if (percent <= -30 && progress > 0.5) {
        out.add(
          InsightComment(
            InsightTone.warn,
            '${range.previous}의 ${(projected / previous.km * 100).round()}% 정도예요. '
            '남은 ${range.isWeek ? "며칠" : "기간"} 동안 한 번만 더 뛰어도 따라잡아요.',
          ),
        );
      }
    }

    // 3. 페이스
    final double? nowPace = current.paceMinPerKm;
    final double? beforePace = previous.paceMinPerKm;
    if (nowPace != null && beforePace != null) {
      final int faster = ((beforePace - nowPace) * 60).round(); // 1km당 몇 초 빨라졌나
      if (faster >= 5) {
        out.add(
          InsightComment(
            InsightTone.good,
            '1km를 ${range.previous}보다 $faster초 빨리 달리고 있어요.',
          ),
        );
      } else if (faster <= -15) {
        out.add(
          InsightComment(
            InsightTone.info,
            '페이스가 1km당 ${-faster}초 느려졌어요. 피곤하다면 천천히 오래 뛰는 것도 좋은 훈련이에요.',
          ),
        );
      }
    }

    // 4. 한 번에 뛰는 거리
    final PeriodSummary latest = current.active ? current : previous;
    if (latest.active && latest.averageKm < 2) {
      out.add(
        const InsightComment(
          InsightTone.info,
          '한 번에 평균 2km가 안 돼요. 다음엔 5분만 더 뛰어 보세요. 지구력이 가장 빨리 느는 방법이에요.',
        ),
      );
    } else if (latest.active && latest.averageKm >= 5) {
      out.add(
        InsightComment(
          InsightTone.good,
          '한 번에 평균 ${latest.averageKm.toStringAsFixed(1)}km를 뛰어요. 탄탄한 지구력이에요.',
        ),
      );
    }

    // 5. 최고 기록
    final PeriodSummary best = periods.reduce((a, b) => a.km >= b.km ? a : b);
    if (best.km > 0 && identical(best, current)) {
      out.add(
        InsightComment(
          InsightTone.good,
          '최근 ${periods.length}$unit 중 ${range.current}가 가장 많이 뛰었어요.',
        ),
      );
    }

    // 6. 목표까지
    if (current.km < range.targetKm) {
      out.add(
        InsightComment(
          InsightTone.info,
          '${range.label} 목표 ${range.targetKm.toStringAsFixed(0)}km까지 '
          '${(range.targetKm - current.km).toStringAsFixed(1)}km 남았어요.',
        ),
      );
    } else {
      out.add(
        InsightComment(
          InsightTone.good,
          '${range.label} 목표 ${range.targetKm.toStringAsFixed(0)}km를 넘었어요!',
        ),
      );
    }

    return out;
  }
}
