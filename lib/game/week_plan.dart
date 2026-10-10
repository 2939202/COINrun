import 'felt_calibration.dart';
import 'goal_policy.dart';
import 'stats_period.dart';
import 'training_model.dart';

// ============================================================
// 이번 주 목표 - 화면과 AI에 넘기는 사실 묶음
//
// 숫자는 전부 여기서 정해집니다. (training_model.dart, goal_policy.dart)
// AI는 목표 범위 안에서 거리를 고르고 이유를 설명할 뿐이고, AI가 실패하면
// 여기 있는 규칙 문장(ruleWhy, rulePlan)을 그대로 씁니다.
// ============================================================

// 이번 주 지금까지 달린 것
class WeekProgress {
  final double km;
  final int runs;
  final double longestKm;

  const WeekProgress({
    required this.km,
    required this.runs,
    required this.longestKm,
  });

  factory WeekProgress.of(List<Session> sessions, DateTime weekStart) {
    double km = 0, longest = 0;
    int runs = 0;
    for (final s in sessions) {
      if (StatsPeriod.weekStart(s.day) != weekStart) continue;
      km += s.km;
      runs += 1;
      if (s.km > longest) longest = s.km;
    }
    return WeekProgress(km: km, runs: runs, longestKm: longest);
  }
}

// 화면의 근거 표시 한 칸 (예: 부하비 1.08)
class Evidence {
  final String label;
  final String value;

  const Evidence(this.label, this.value);
}

class WeekFacts {
  static const List<String> weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  final WeekGoal goal;
  final TrainingState state;
  final GoalResult? last;
  final FeltCalibration felt;
  final WeekProgress progress;
  final List<int> habitDays; // 자주 달린 요일 (0=월), 많은 순

  const WeekFacts({
    required this.goal,
    required this.state,
    required this.last,
    required this.felt,
    required this.progress,
    required this.habitDays,
  });

  factory WeekFacts.build({
    required List<Session> sessions,
    required DateTime now,
    GoalResult? last,
    required FeltCalibration felt,
  }) {
    final DateTime weekStart = StatsPeriod.weekStart(now);
    final WeekGoal goal = GoalPolicy.plan(
      sessions,
      now,
      last: last,
      felt: felt,
    );
    final List<int> count = List.filled(7, 0);
    for (final s in sessions) {
      count[s.day.weekday - 1] += 1;
    }
    final List<int> days = [for (int d = 0; d < 7; d++) d]
      ..removeWhere((d) => count[d] == 0)
      ..sort((a, b) => count[b].compareTo(count[a]));
    return WeekFacts(
      goal: goal,
      // 근거도 목표를 정한 시점(이번 주 시작 직전)의 값으로 보여줍니다.
      // 주 중의 값을 보여주면 목표를 정한 이유와 숫자가 어긋나 보입니다.
      state: TrainingModel.analyze(
        sessions.where((s) => s.day.isBefore(weekStart)).toList(),
        DateTime(weekStart.year, weekStart.month, weekStart.day - 1),
      ),
      last: last,
      felt: felt,
      progress: WeekProgress.of(sessions, weekStart),
      habitDays: days.take(goal.runs).toList()..sort(),
    );
  }

  String get habitDayText => habitDays.map((d) => weekdays[d]).join('·');

  int? get lastAttainmentPercent {
    final GoalResult? l = last;
    return l == null ? null : (l.attainment * 100).round();
  }

  // Gemini에게 보내는 사실. 이름과 경로는 넣지 않습니다.
  String toPrompt() {
    final StringBuffer out = StringBuffer()
      ..writeln('훈련 단계: ${goal.stage.label}')
      ..writeln('지난 4주 주간 평균 거리: ${goal.baseKm.toStringAsFixed(1)}km')
      ..writeln(
        '이번 주 목표 거리 허용 범위: '
        '${goal.minKm.toStringAsFixed(1)}km ~ ${goal.maxKm.toStringAsFixed(1)}km',
      )
      ..writeln('이번 주 목표 횟수: ${goal.runs}회')
      ..writeln('이번 주 1회 최장 거리 목표: ${goal.longestKm.toStringAsFixed(1)}km')
      ..writeln('범위를 정한 이유: ${goal.reasons.map(_reasonText).join(', ')}')
      ..writeln('역치 페이스 추정: ${_pace(state.thresholdPace)}')
      ..writeln(
        '체력 ${state.fitness.round()}, 피로 ${state.fatigue.round()}, '
        '컨디션 ${state.form.round()}',
      );
    final double? acwr = state.acwr;
    if (acwr != null) {
      out.writeln('급성:만성 부하비: ${acwr.toStringAsFixed(2)} (1.3 초과 시 무리)');
    }
    final double? p5 = state.predicted5k;
    if (p5 != null) out.writeln('5km 예상 기록: ${_time(p5)}');
    final int? pct = lastAttainmentPercent;
    if (last != null && pct != null) {
      out.writeln(
        '지난주 목표: ${last!.goalKm.toStringAsFixed(1)}km, '
        '실제: ${last!.actualKm.toStringAsFixed(1)}km, 달성률: $pct%',
      );
    }
    final double? bias = felt.bias;
    if (bias != null) {
      out.writeln(
        '체감 부하도와 계산 부하도의 평균 차이: ${bias.toStringAsFixed(1)}단계 '
        '(양수면 계산보다 힘들게 느낌, ${felt.runs}회)',
      );
    }
    if (habitDays.isNotEmpty) out.writeln('주로 달린 요일: $habitDayText');
    out.write(
      '이번 주 지금까지: ${progress.runs}회, ${progress.km.toStringAsFixed(1)}km',
    );
    return out.toString();
  }

  // 화면에 칩으로 보여줄 근거
  List<Evidence> get evidence => [
    Evidence('단계', goal.stage.label),
    if (state.acwr != null) Evidence('부하비', state.acwr!.toStringAsFixed(2)),
    Evidence('컨디션', '${state.form.round()}'),
    if (lastAttainmentPercent != null)
      Evidence('지난주 달성', '$lastAttainmentPercent%'),
    if (state.predicted5k != null)
      Evidence('5km 예상', _time(state.predicted5k!)),
    if (felt.bias != null)
      Evidence(
        '체감',
        '${felt.bias! >= 0 ? '+' : ''}${felt.bias!.toStringAsFixed(1)}',
      ),
  ];

  // AI가 없을 때 쓰는 이유 문장. 모두 "습니다/입니다"로 끝납니다.
  String ruleWhy() {
    final List<String> out = [];
    final List<GoalReason> r = goal.reasons;
    final String base = goal.baseKm.toStringAsFixed(1);
    if (r.contains(GoalReason.coldStart)) {
      out.add(
        '기록이 아직 적어 주 ${goal.runs}회, '
        '${goal.minKm.toStringAsFixed(1)}km부터 시작하는 것이 좋습니다.',
      );
    } else if (r.contains(GoalReason.recovery)) {
      out.add(
        '최근 부담이 크게 늘어 이번 주는 지난 4주 평균 ${base}km보다 '
        '줄인 범위입니다.',
      );
    } else if (r.contains(GoalReason.returning)) {
      out.add(
        '최근 달린 양이 줄어 지난 4주 평균 ${base}km 수준에서 '
        '천천히 늘리는 범위입니다.',
      );
    } else {
      out.add('지난 4주 평균 ${base}km를 기준으로 조금 늘린 범위입니다.');
    }
    final int? pct = lastAttainmentPercent;
    if (pct != null) out.add('지난주 목표의 $pct%를 달렸습니다.');
    if (r.contains(GoalReason.feltHarder)) {
      out.add('계산보다 힘들게 느낀 날이 많아 늘리는 폭을 줄였습니다.');
    } else if (r.contains(GoalReason.feltEasier)) {
      out.add('계산보다 쉽게 느낀 날이 많아 늘리는 폭을 조금 키웠습니다.');
    }
    return out.join(' ');
  }

  List<String> rulePlan() {
    final double each = goal.suggestedKm / goal.runs;
    return [
      if (habitDays.length >= goal.runs)
        '평소처럼 $habitDayText에 달리는 것이 좋습니다.'
      else
        '이틀에 한 번꼴로 나누어 달리는 것이 좋습니다.',
      '한 번에 ${each.toStringAsFixed(1)}km 안팎이면 목표에 닿습니다.',
    ];
  }

  static String _reasonText(GoalReason r) => switch (r) {
    GoalReason.coldStart => '기록이 적어 입문 기준',
    GoalReason.progress => '평소보다 조금 더',
    GoalReason.recovery => '부담이 커서 회복 주',
    GoalReason.returning => '쉬다 돌아와서 천천히',
    GoalReason.attainmentHigh => '지난 목표 달성',
    GoalReason.attainmentLow => '지난 목표가 버거움',
    GoalReason.feltHarder => '계산보다 힘들게 느낌',
    GoalReason.feltEasier => '계산보다 쉽게 느낌',
  };

  static String _pace(double minPerKm) {
    final int total = (minPerKm * 60).round();
    return "${total ~/ 60}'${(total % 60).toString().padLeft(2, '0')}\"/km";
  }

  static String _time(double seconds) {
    final int s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

// 저장되는 이번 주 목표. 한 주 동안 바뀌지 않습니다.
class WeekPlan {
  final String weekKey;
  final double km; // 고른 목표 거리 (범위 안)
  final int runs;
  final double longestKm;
  final String why;
  final List<String> plan;
  final bool writtenByAi;

  const WeekPlan({
    required this.weekKey,
    required this.km,
    required this.runs,
    required this.longestKm,
    required this.why,
    required this.plan,
    required this.writtenByAi,
  });

  factory WeekPlan.rule(String weekKey, WeekFacts facts) => WeekPlan(
    weekKey: weekKey,
    km: facts.goal.suggestedKm,
    runs: facts.goal.runs,
    longestKm: facts.goal.longestKm,
    why: facts.ruleWhy(),
    plan: facts.rulePlan(),
    writtenByAi: false,
  );

  Map<String, dynamic> toMap() => {
    'weekKey': weekKey,
    'km': km,
    'runs': runs,
    'longestKm': longestKm,
    'why': why,
    'plan': plan,
    'writtenByAi': writtenByAi,
  };

  static WeekPlan? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final double? km = (map['km'] as num?)?.toDouble();
    if (km == null) return null;
    return WeekPlan(
      weekKey: map['weekKey'] as String? ?? '',
      km: km,
      runs: (map['runs'] as num?)?.toInt() ?? 2,
      longestKm: (map['longestKm'] as num?)?.toDouble() ?? 0,
      why: map['why'] as String? ?? '',
      plan: [for (final p in (map['plan'] as List<dynamic>? ?? const [])) '$p'],
      writtenByAi: map['writtenByAi'] as bool? ?? false,
    );
  }
}
