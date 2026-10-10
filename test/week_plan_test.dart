import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contact/game/felt_calibration.dart';
import 'package:contact/game/goal_policy.dart';
import 'package:contact/game/training_model.dart';
import 'package:contact/game/week_plan.dart';
import 'package:contact/models/run_log.dart';
import 'package:contact/services/ai_coach.dart';
import 'package:contact/services/ai_guard.dart';
import 'package:contact/services/week_coach.dart';
import 'package:flutter_test/flutter_test.dart';

// 기준일: 2026-10-07 수요일. 이번 주는 10/5(월)부터입니다.
final DateTime now = DateTime(2026, 10, 7, 12);
final DateTime thisMonday = DateTime(2026, 10, 5);

Session run(int weeksBack, int dayOfWeek, double km, {double pace = 6.5}) {
  final int seconds = (km * pace * 60).round();
  return Session(
    day: DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day - 7 * weeksBack + dayOfWeek,
    ),
    km: km,
    movingSeconds: seconds,
    steps: 165 * seconds ~/ 60,
  );
}

// 4주 동안 주 3회 4km (월·수·토) + 이번 주 월요일 4km
List<Session> steady() => [
  for (int w = 1; w <= 4; w++) ...[run(w, 0, 4), run(w, 2, 4), run(w, 5, 4)],
  run(0, 0, 4),
];

RunLog felt(int daysAgo, int computed, int chosen) =>
    RunLog.fromMap('f$daysAgo', {
      'createdAt': Timestamp.fromDate(now.subtract(Duration(days: daysAgo))),
      'loadLevel': computed,
      'feltLevel': chosen,
    });

WeekFacts facts({GoalResult? last, FeltCalibration? calibration}) =>
    WeekFacts.build(
      sessions: steady(),
      now: now,
      last: last,
      felt: calibration ?? const FeltCalibration(bias: null, runs: 0),
    );

void main() {
  group('숫자 충실성 검사', () {
    final allowed = AiGuard.allowedFrom('지난주 12.0km, 이번 주 4.0km, 달성률 105%');

    test('보낸 숫자, 그 차이, 그 비율은 통과', () {
      expect(AiGuard.supported('지난주 12.0km를 달렸습니다.', allowed), isTrue);
      expect(AiGuard.supported('8km 줄었습니다.', allowed), isTrue); // 12 - 4
      expect(AiGuard.supported('지난주의 33% 수준입니다.', allowed), isTrue); // 4/12
      expect(AiGuard.supported('주 3회 달렸습니다.', allowed), isTrue); // 0~7 정수
    });

    test('보내지 않은 숫자는 걸린다', () {
      expect(AiGuard.supported('심박이 145까지 올랐습니다.', allowed), isFalse);
      expect(AiGuard.supported('21.3km를 달렸습니다.', allowed), isFalse);
    });
  });

  group('체감 보정', () {
    test('3번 이상 모여야 쓴다', () {
      final c = FeltCalibration.of([felt(1, 2, 4), felt(3, 2, 4)], now);
      expect(c.bias, isNull);
    });

    test('계산보다 꾸준히 힘들게 느끼면 목표를 덜 올린다', () {
      final c = FeltCalibration.of([
        felt(1, 2, 3),
        felt(3, 2, 4),
        felt(5, 3, 4),
      ], now);
      expect(c.bias, closeTo(4 / 3, 1e-9));
      expect(c.feelsHarder, isTrue);
      final plain = GoalPolicy.plan(steady(), now);
      final eased = GoalPolicy.plan(steady(), now, felt: c);
      expect(eased.reasons, contains(GoalReason.feltHarder));
      expect(eased.maxKm, lessThan(plain.maxKm));
    });

    test('28일보다 오래된 기록은 보지 않는다', () {
      final c = FeltCalibration.of([
        felt(30, 2, 5),
        felt(31, 2, 5),
        felt(40, 2, 5),
      ], now);
      expect(c.bias, isNull);
    });
  });

  group('이번 주 목표의 사실 묶음', () {
    test('Gemini에게 범위와 근거 숫자를 보낸다', () {
      final f = facts(last: const GoalResult(goalKm: 12.4, actualKm: 13));
      final prompt = f.toPrompt();
      expect(
        prompt,
        contains('이번 주 목표 거리 허용 범위: ${f.goal.minKm.toStringAsFixed(1)}km'),
      );
      expect(prompt, contains('달성률: 105%'));
      expect(prompt, contains('주로 달린 요일: 월·수·토'));
      expect(prompt, contains('이번 주 지금까지: 1회, 4.0km'));
    });

    test('규칙 문장은 모두 "습니다/입니다"로 끝난다', () {
      for (final f in [
        facts(),
        facts(last: const GoalResult(goalKm: 12, actualKm: 6)),
        facts(calibration: const FeltCalibration(bias: 1.2, runs: 4)),
        WeekFacts.build(
          sessions: const [],
          now: now,
          felt: const FeltCalibration(bias: null, runs: 0),
        ),
      ]) {
        expect(AiCoach.isFormal(f.ruleWhy()), isTrue, reason: f.ruleWhy());
        for (final line in f.rulePlan()) {
          expect(AiCoach.isFormal(line), isTrue, reason: line);
        }
      }
    });

    test('이번 주 진행을 센다', () {
      final f = facts();
      expect(f.progress.runs, 1);
      expect(f.progress.km, 4);
    });

    test('근거 칩에 단계와 달성률이 들어간다', () {
      final f = facts(last: const GoalResult(goalKm: 12, actualKm: 9));
      final labels = f.evidence.map((e) => e.label).toList();
      expect(labels, contains('단계'));
      expect(labels, contains('지난주 달성'));
    });
  });

  group('Gemini 목표 답 읽기', () {
    final f = facts(last: const GoalResult(goalKm: 12.4, actualKm: 13));
    final String sent = f.toPrompt();
    String answer(Map<String, Object> m) => jsonEncode(m);

    test('실제 답: 범위 안 목표와 숫자 근거가 맞으면 그대로 쓴다', () {
      final plan = WeekCoach.parse(
        answer({
          'goalKm': f.goal.maxKm,
          'why': '지난주 목표 달성률이 105%로 점진적인 거리 증가가 가능한 상태입니다.',
          'plan': ['월요일과 수요일에 나누어 달리는 것이 좋습니다.'],
        }),
        key: 'w2026-10-05',
        facts: f,
        sent: sent,
      );
      expect(plan!.writtenByAi, isTrue);
      expect(plan.km, f.goal.maxKm);
      expect(plan.why, contains('105%'));
    });

    test('범위 밖 목표는 끝값으로 자른다', () {
      final plan = WeekCoach.parse(
        answer({
          'goalKm': 40,
          'why': '거리를 늘리는 것이 좋습니다.',
          'plan': ['나누어 달리는 것이 좋습니다.'],
        }),
        key: 'k',
        facts: f,
        sent: sent,
      );
      expect(plan!.km, f.goal.maxKm);
    });

    test('남은 거리를 횟수로 나눈 숫자는 허용한다', () {
      final double goal = f.goal.minKm;
      final double left = goal - f.progress.km;
      final int leftRuns = f.goal.runs - f.progress.runs;
      final plan = WeekCoach.parse(
        answer({
          'goalKm': goal,
          'why': '지난 4주 평균을 기준으로 한 범위입니다.',
          'plan': [
            '남은 $leftRuns회 동안 ${left.toStringAsFixed(1)}km를 '
                '나누어 달리는 것이 좋습니다.',
          ],
        }),
        key: 'k',
        facts: f,
        sent: sent,
      );
      expect(plan!.plan.single, contains(left.toStringAsFixed(1)));
    });

    test('지어낸 숫자가 든 이유는 규칙 문장으로 바꾼다', () {
      final plan = WeekCoach.parse(
        answer({
          'goalKm': f.goal.minKm,
          'why': '최대 심박수 182를 고려한 범위입니다.',
          'plan': ['월요일에 달리는 것이 좋습니다.'],
        }),
        key: 'k',
        facts: f,
        sent: sent,
      );
      expect(plan!.why, f.ruleWhy());
    });

    test('말투를 어긴 계획 문장은 버리고, 다 버려지면 규칙 계획을 쓴다', () {
      final plan = WeekCoach.parse(
        answer({
          'goalKm': f.goal.minKm,
          'why': '지난 4주 평균을 기준으로 한 범위입니다.',
          'plan': ['월요일에 달려 보세요!'],
        }),
        key: 'k',
        facts: f,
        sent: sent,
      );
      expect(plan!.plan, f.rulePlan());
    });

    test('형식이 틀리면 null (규칙 목표를 씁니다)', () {
      expect(WeekCoach.parse('목표입니다.', key: 'k', facts: f, sent: sent), isNull);
      expect(
        WeekCoach.parse(
          answer({'why': '이유입니다.'}),
          key: 'k',
          facts: f,
          sent: sent,
        ),
        isNull,
      );
    });
  });

  test('저장한 목표를 그대로 다시 읽는다', () {
    final plan = WeekPlan.rule('w2026-10-05', facts());
    final back = WeekPlan.fromMap(plan.toMap())!;
    expect(back.km, plan.km);
    expect(back.runs, plan.runs);
    expect(back.plan, plan.plan);
    expect(back.writtenByAi, isFalse);
  });
}
