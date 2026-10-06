import 'package:contact/game/goal_policy.dart';
import 'package:contact/game/training_model.dart';
import 'package:flutter_test/flutter_test.dart';

// 기준일: 2026-10-07 수요일. 이번 주는 10/5(월)부터, 지난주는 9/28부터입니다.
final DateTime now = DateTime(2026, 10, 7, 12);
final DateTime thisMonday = DateTime(2026, 10, 5);

// 이번 주 월요일에서 weeksBack주 전 주의 dayOfWeek(0=월)에 뛴 기록
Session run(
  int weeksBack,
  int dayOfWeek,
  double km, {
  double pace = 6.5,
  int? cadence = 165,
}) {
  final int seconds = (km * pace * 60).round();
  return Session(
    day: DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day - 7 * weeksBack + dayOfWeek,
    ),
    km: km,
    movingSeconds: seconds,
    steps: cadence == null ? 0 : (cadence * seconds / 60).round(),
    stepsEstimated: cadence == null,
  );
}

// 4주 동안 주 3회 4km (월·수·토)
List<Session> steady() => [
  for (int w = 1; w <= 4; w++) ...[run(w, 0, 4), run(w, 2, 4), run(w, 5, 4)],
];

void main() {
  group('훈련 부하 모델', () {
    test('기록이 없으면 역치는 입문 기본값, 부하는 0', () {
      final state = TrainingModel.analyze(const [], now);
      expect(state.thresholdPace, TrainingModel.defaultThresholdPace);
      expect(state.thresholdFromRuns, 0);
      expect(state.fitness, 0);
      expect(state.acwr, isNull);
      expect(state.predicted5k, isNull);
    });

    test('역치로 1시간 달리면 부하 100 (rTSS 정의)', () {
      final s = Session(
        day: DateTime(2026, 10, 1),
        km: 10,
        movingSeconds: 3600,
        steps: 165 * 60,
      );
      expect(TrainingModel.loadOf(s, 6.0), closeTo(100, 1e-6));
    });

    test('같은 시간이라도 느리면 부하가 작다 (강도의 제곱)', () {
      final fast = Session(
        day: DateTime(2026, 10, 1),
        km: 6,
        movingSeconds: 1800,
        steps: 5000,
      );
      final slow = Session(
        day: DateTime(2026, 10, 1),
        km: 4,
        movingSeconds: 1800,
        steps: 5000,
      );
      expect(
        TrainingModel.loadOf(fast, 6),
        greaterThan(TrainingModel.loadOf(slow, 6)),
      );
    });

    test('케이던스 140 미만은 걷기로 보고 강도를 0.6 이하로 묶는다', () {
      final walk = run(1, 0, 3, pace: 6.0, cadence: 110);
      expect(walk.isWalk, isTrue);
      expect(TrainingModel.intensityOf(walk, 6.0), lessThanOrEqualTo(0.6));
    });

    test('추정 걸음이면 케이던스를 믿지 않고 페이스로 걷기를 판단', () {
      expect(run(1, 0, 3, pace: 6.5, cadence: null).isWalk, isFalse);
      expect(run(1, 0, 3, pace: 12, cadence: null).isWalk, isTrue);
    });

    test('기록이 많을수록 역치가 실제 기록 쪽으로 다가간다 (축소 추정)', () {
      // 5km 30분(6분/km) -> 10km 환산 약 62.5분 -> 6.25분/km x 1.04 = 약 6.5
      final one = TrainingModel.analyze([run(1, 0, 5, pace: 6)], now);
      final many = TrainingModel.analyze([
        for (int i = 0; i < 12; i++) run(1 + i ~/ 3, i % 3 * 2, 5, pace: 6),
      ], now);
      expect(one.thresholdPace, greaterThan(many.thresholdPace));
      expect(many.thresholdPace, closeTo(6.6, 0.15));
    });

    test('Riegel 공식으로 5km, 10km 기록을 예측한다', () {
      final state = TrainingModel.analyze([run(1, 0, 5, pace: 6)], now);
      expect(state.predicted5k, closeTo(1800, 1));
      expect(state.predicted10k! / 60, closeTo(62.6, 0.3));
    });

    test('꾸준히 뛰면 ACWR이 1 근처 (한 주를 마친 일요일 밤 기준)', () {
      final state = TrainingModel.analyze(steady(), DateTime(2026, 10, 4));
      expect(state.acwr, closeTo(1.0, 0.35));
      expect(state.overreaching, isFalse);
    });

    test('같은 기록이면 언제나 같은 결과 (재현성)', () {
      final a = TrainingModel.analyze(steady(), now);
      final b = TrainingModel.analyze(steady(), now);
      expect(a.fitness, b.fitness);
      expect(a.acwr, b.acwr);
      expect(a.thresholdPace, b.thresholdPace);
    });
  });

  group('이번 주 목표 - 사용자 유형별', () {
    test('막 시작한 사람: 입문 기본값 (주 2회, 4km부터)', () {
      final goal = GoalPolicy.plan([run(1, 0, 1.5), run(1, 3, 2)], now);
      expect(goal.stage, TrainingStage.beginner);
      expect(goal.reasons, contains(GoalReason.coldStart));
      expect(goal.runs, 2);
      expect(goal.minKm, 4);
      expect(goal.weekStart, thisMonday);
    });

    test('꾸준한 사람: 평소(주 12km)의 0~10% 더, 횟수는 평소대로', () {
      final goal = GoalPolicy.plan(steady(), now);
      expect(goal.stage, TrainingStage.building);
      expect(goal.reasons, contains(GoalReason.progress));
      expect(goal.baseKm, closeTo(12, 1e-9));
      expect(goal.minKm, 12);
      expect(goal.maxKm, 13.2);
      expect(goal.runs, 3);
      expect(goal.longestKm, 4.4);
    });

    test('갑자기 많이 뛴 사람: 늘리지 않고 회복 주', () {
      final sessions = [
        for (int w = 2; w <= 4; w++) ...[run(w, 0, 3), run(w, 3, 3)],
        // 지난주에 갑자기 세 배
        run(1, 0, 6), run(1, 1, 6), run(1, 3, 6), run(1, 5, 7),
      ];
      final goal = GoalPolicy.plan(sessions, now);
      expect(goal.reasons, contains(GoalReason.recovery));
      expect(goal.maxKm, lessThan(goal.baseKm));
    });

    test('쉬다 돌아온 사람: 천천히', () {
      final sessions = [
        // 3~4주 전에는 꾸준했고, 지난 2주는 쉬다가 지난주 막판에 한 번
        for (int w = 3; w <= 4; w++) ...[
          run(w, 0, 5),
          run(w, 2, 5),
          run(w, 4, 5),
        ],
        run(1, 6, 2),
      ];
      final goal = GoalPolicy.plan(sessions, now);
      expect(goal.reasons, contains(GoalReason.returning));
      expect(goal.maxKm, lessThanOrEqualTo(goal.baseKm * 1.05 + 0.05));
    });

    test('지난 목표를 넘겼으면 조금 더 올리고 1회 더', () {
      final base = GoalPolicy.plan(steady(), now);
      final up = GoalPolicy.plan(
        steady(),
        now,
        last: const GoalResult(goalKm: 12, actualKm: 13),
      );
      expect(up.reasons, contains(GoalReason.attainmentHigh));
      expect(up.maxKm, greaterThan(base.maxKm));
      expect(up.runs, base.runs + 1);
    });

    test('지난 목표가 버거웠으면 내린다', () {
      final down = GoalPolicy.plan(
        steady(),
        now,
        last: const GoalResult(goalKm: 12, actualKm: 6),
      );
      expect(down.reasons, contains(GoalReason.attainmentLow));
      expect(down.minKm, lessThan(12));
      expect(down.maxKm, lessThanOrEqualTo(12));
    });

    test('이번 주 기록은 이번 주 목표에 섞이지 않는다 (주 중에 흔들리지 않음)', () {
      final monday = GoalPolicy.plan(steady(), DateTime(2026, 10, 5, 8));
      final friday = GoalPolicy.plan([
        ...steady(),
        run(0, 1, 10),
        run(0, 3, 10),
      ], DateTime(2026, 10, 9, 20));
      expect(friday.minKm, monday.minKm);
      expect(friday.maxKm, monday.maxKm);
    });

    test('LLM이 범위 밖 숫자를 내도 범위 끝으로 잘린다', () {
      final goal = GoalPolicy.plan(steady(), now);
      expect(goal.clampKm(30), goal.maxKm);
      expect(goal.clampKm(1), goal.minKm);
      expect(goal.clampKm(12.64), 12.6);
    });
  });
}
