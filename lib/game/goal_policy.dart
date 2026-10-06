import 'dart:math';

import 'stats_period.dart';
import 'training_model.dart';

// ============================================================
// 이번 주 목표의 허용 범위
//
// 목표는 한 주에 한 번, 그 주가 시작되기 전까지 끝난 4주의 기록으로 정합니다.
// 진행 중인 이번 주를 섞으면 수요일에는 평균이 낮게 나와서 목표가 매일 흔들립니다.
//
// 목표 숫자는 이 범위를 벗어날 수 없습니다. LLM은 범위 안에서 고르고 이유를 쓰기만 합니다.
// 범위 밖의 숫자를 내면 범위 끝값으로 잘립니다. (clamp)
//
// [근거]
//   - 목표 설정 이론(Locke & Latham): 구체적이고, 어렵지만 닿을 수 있는 목표가 성과를 높입니다.
//     그래서 "더 뛰세요"가 아니라 횟수, 거리, 1회 최장 거리를 숫자로 줍니다.
//   - 지난 목표 달성률로 난이도를 조절합니다. 달성하면 조금 올리고, 70% 미만이면 내립니다.
//     목표가 대체로 닿을 만한 수준(달성률 70~100%)에 머물도록 하는 단순한 되먹임입니다.
//   - 부하가 갑자기 늘었거나(ACWR > 1.3) 피로가 크면 늘리지 않고 회복 주로 둡니다.
//
// [단계]
//   시작 전 -> 입문 -> 습관 만들기 -> 거리 늘리기 -> 유지·속도
// ============================================================
enum TrainingStage {
  notStarted('시작 전'),
  beginner('입문'),
  habit('습관 만들기'),
  building('거리 늘리기'),
  maintaining('유지·속도');

  final String label;
  const TrainingStage(this.label);
}

// 범위를 이렇게 정한 이유. 화면의 근거 표시와 LLM 입력에 같이 씁니다.
enum GoalReason {
  coldStart, // 기록이 적어 입문 기본값
  progress, // 평소보다 조금 더
  recovery, // 무리하는 중이라 줄임
  returning, // 쉬다 돌아와서 천천히
  attainmentHigh, // 지난 목표를 달성해서 올림
  attainmentLow, // 지난 목표가 버거워서 내림
}

class WeekGoal {
  final DateTime weekStart;
  final TrainingStage stage;
  final double minKm;
  final double maxKm;
  final int runs;
  final double longestKm;
  final double baseKm; // 기준이 된 최근 4주 평균
  final List<GoalReason> reasons;

  const WeekGoal({
    required this.weekStart,
    required this.stage,
    required this.minKm,
    required this.maxKm,
    required this.runs,
    required this.longestKm,
    required this.baseKm,
    required this.reasons,
  });

  // 범위 가운데. LLM 답이 없을 때 이 값을 목표로 씁니다.
  double get suggestedKm => _round((minKm + maxKm) / 2);

  // LLM이 고른 값을 범위 안으로 넣습니다.
  double clampKm(double km) => _round(km.clamp(minKm, maxKm));

  static double _round(double km) => (km * 10).round() / 10;
}

// 지난 목표 하나의 결과
class GoalResult {
  final double goalKm;
  final double actualKm;

  const GoalResult({required this.goalKm, required this.actualKm});

  double get attainment => goalKm <= 0 ? 0 : actualKm / goalKm;
}

class GoalPolicy {
  GoalPolicy._();

  // 지난주가 그 앞 3주 평균의 60%에도 못 미치면 쉬다 돌아온 것으로 봅니다.
  // ACWR은 하루 단위라 한 번 뛴 날 크게 출렁여서, 주 단위로 한 번 더 봅니다.
  static bool _droppedOff(List<double> weekKm) {
    final double before = (weekKm[1] + weekKm[2] + weekKm[3]) / 3;
    return before > 0 && weekKm[0] < before * 0.6;
  }

  static const int lookbackWeeks = 4;
  static const int maxRuns = 5;

  // 입문 기본 목표: 주 2회, 합계 4km
  static const double beginnerKm = 4;
  static const int beginnerRuns = 2;

  // 기록 전부를 받아, 이번 주가 시작되기 전(지난 일요일 밤) 기준으로 목표를 정합니다.
  static WeekGoal plan(
    List<Session> sessions,
    DateTime now, {
    GoalResult? last,
  }) {
    final DateTime thisWeek = StatsPeriod.weekStart(now);
    final DateTime sunday = DateTime(
      thisWeek.year,
      thisWeek.month,
      thisWeek.day - 1,
    );
    final TrainingState before = TrainingModel.analyze(
      sessions.where((s) => s.day.isBefore(thisWeek)).toList(),
      sunday,
    );
    return forWeek(before, now, last: last);
  }

  // state는 이번 주가 시작되기 전까지의 기록으로 만든 것이어야 합니다. (plan이 맞춰 줍니다)
  static WeekGoal forWeek(
    TrainingState state,
    DateTime now, {
    GoalResult? last,
  }) {
    final DateTime thisWeek = StatsPeriod.weekStart(now);

    // 끝난 4주의 주간 거리와 횟수 (지난주가 0번 칸)
    final List<double> weekKm = List.filled(lookbackWeeks, 0);
    final List<int> weekRuns = List.filled(lookbackWeeks, 0);
    double longest = 0;
    for (final s in state.sessions) {
      final int back =
          thisWeek.difference(StatsPeriod.weekStart(s.day)).inDays ~/ 7 - 1;
      if (back < 0 || back >= lookbackWeeks) continue;
      weekKm[back] += s.km;
      weekRuns[back] += 1;
      longest = max(longest, s.km);
    }
    final int activeWeeks = weekRuns.where((r) => r > 0).length;
    final int totalRuns = weekRuns.fold(0, (a, b) => a + b);
    final double baseKm =
        weekKm.fold<double>(0, (a, b) => a + b) / lookbackWeeks;

    final List<GoalReason> reasons = [];

    // 단계
    final TrainingStage stage;
    if (state.sessions.isEmpty) {
      stage = TrainingStage.notStarted;
    } else if (activeWeeks <= 1 || totalRuns < 4) {
      stage = TrainingStage.beginner;
    } else if (activeWeeks < lookbackWeeks) {
      stage = TrainingStage.habit;
    } else if (baseKm < 15) {
      stage = TrainingStage.building;
    } else {
      stage = TrainingStage.maintaining;
    }

    // 기록이 적으면 입문 기본값에서 시작합니다.
    if (stage == TrainingStage.notStarted || stage == TrainingStage.beginner) {
      reasons.add(GoalReason.coldStart);
      final double base = max(baseKm, beginnerKm);
      return WeekGoal(
        weekStart: thisWeek,
        stage: stage,
        minKm: WeekGoal._round(base),
        maxKm: WeekGoal._round(base * 1.15),
        runs: beginnerRuns,
        longestKm: WeekGoal._round(max(2, min(longest * 1.1, longest + 1))),
        baseKm: baseKm,
        reasons: reasons,
      );
    }

    // 늘리는 폭: 기본 +0~10%
    double low = 1.0, high = 1.10;
    if (state.overreaching) {
      low = 0.70;
      high = 0.85;
      reasons.add(GoalReason.recovery);
    } else if (state.detraining || _droppedOff(weekKm)) {
      low = 0.9;
      high = 1.05;
      reasons.add(GoalReason.returning);
    } else {
      reasons.add(GoalReason.progress);
    }

    // 지난 목표 달성률로 조절 (회복 주에는 올리지 않습니다)
    final double? attainment = last?.attainment;
    if (attainment != null && !state.overreaching) {
      if (attainment >= 1.0) {
        high += 0.03;
        reasons.add(GoalReason.attainmentHigh);
      } else if (attainment < 0.7) {
        low -= 0.10;
        high = min(high, 1.0);
        reasons.add(GoalReason.attainmentLow);
      }
    }

    // 횟수: 평소 횟수(활동한 주의 평균). 달성했으면 1회 더, 최대 5회
    final List<int> active = weekRuns.where((r) => r > 0).toList();
    int runs = (active.fold(0, (a, b) => a + b) / active.length).round();
    if (attainment != null && attainment >= 1.0 && !state.overreaching) {
      runs += 1;
    }
    if (state.overreaching) runs = max(2, runs - 1);
    runs = runs.clamp(2, maxRuns);

    // 1회 최장: 지금 최장의 10% 또는 1.5km 중 작은 만큼만 늘립니다. 회복 주에는 그대로
    final double longestKm = state.overreaching
        ? longest
        : min(longest * 1.1, longest + 1.5);

    return WeekGoal(
      weekStart: thisWeek,
      stage: stage,
      minKm: WeekGoal._round(baseKm * low),
      maxKm: WeekGoal._round(baseKm * high),
      runs: runs,
      longestKm: WeekGoal._round(longestKm),
      baseKm: baseKm,
      reasons: reasons,
    );
  }
}
