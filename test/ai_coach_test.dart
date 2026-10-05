import 'dart:convert';

import 'package:contact/game/run_insights.dart';
import 'package:contact/models/run_stats.dart';
import 'package:contact/services/ai_coach.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-07 수요일 정오. 이번 주는 10/5(월)에 시작했습니다.
final DateTime wednesday = DateTime(2026, 10, 7, 12);

RunStats _week(String key, {int runs = 2, double km = 6, int movingMin = 36}) =>
    RunStats(
      key: key,
      startAt: null,
      isWeek: true,
      runs: runs,
      distanceMeters: km * 1000,
      seconds: movingMin * 60,
      movingSeconds: movingMin * 60,
      steps: 0,
      gold: 0,
      exp: 0,
    );

InsightReport _report({double thisWeekKm = 4}) => RunInsights.analyze(
  range: InsightRange.week,
  statsByKey: {
    for (final w in [
      _week('w2026-09-14', km: 8),
      _week('w2026-09-21', km: 10, movingMin: 60),
      _week('w2026-09-28', km: 12, runs: 3, movingMin: 70),
      _week('w2026-10-05', km: thisWeekKm, runs: 1, movingMin: 25),
    ])
      w.key: w,
  },
  now: wednesday,
);

void main() {
  group('Gemini에게 보내는 내용', () {
    test('기간별 숫자와 점수가 들어간다', () {
      final String prompt = AiCoach.buildPrompt(_report());
      expect(prompt, contains('주간'));
      expect(prompt, contains('이번 주: 1회, 4.00km, 움직인 시간 25분'));
      expect(prompt, contains('1주 전: 3회, 12.00km'));
      expect(prompt, contains('점수: '));
      expect(prompt, contains('경과율: 36%'));
    });

    test('뛰지 않은 주도 0으로 들어가고 페이스는 없음으로 적는다', () {
      final String prompt = AiCoach.buildPrompt(_report());
      expect(prompt, contains('5주 전: 0회, 0.00km, 움직인 시간 0분, 페이스 없음'));
    });

    test('같은 기록이면 같은 키, 기록이 바뀌면 다른 키', () {
      expect(AiCoach.inputKey(_report()), AiCoach.inputKey(_report()));
      expect(
        AiCoach.inputKey(_report()),
        isNot(AiCoach.inputKey(_report(thisWeekKm: 5))),
      );
    });
  });

  group('Gemini 답 읽기', () {
    String answer(Map<String, Object> map) => jsonEncode(map);

    test('정상 답을 읽는다', () {
      final words = AiCoach.parse(
        answer({
          'headline': '이번 주는 4.0km를 기록하였습니다.',
          'comments': [
            {'tone': 'good', 'text': '지난 4주 중 3주를 달리셨습니다.'},
            {'tone': 'warn', 'text': '이번 주 예상 거리는 지난주보다 적습니다.'},
          ],
        }),
      );
      expect(words, isNotNull);
      expect(words!.headline, '이번 주는 4.0km를 기록하였습니다.');
      expect(words.comments.length, 2);
      expect(words.comments.first.tone, InsightTone.good);
      expect(words.comments.last.tone, InsightTone.warn);
    });

    test('이모지와 느낌표는 지운다', () {
      final words = AiCoach.parse(
        answer({
          'headline': '잘하셨습니다! 🏃‍♂️🔥',
          'comments': [
            {'tone': 'good', 'text': '꾸준히 달렸습니다 👍'},
          ],
        }),
      );
      expect(words!.headline, '잘하셨습니다');
      expect(words.comments.first.text, '꾸준히 달렸습니다');
    });

    test('모르는 tone은 info로 둔다', () {
      final words = AiCoach.parse(
        answer({
          'headline': '요약입니다.',
          'comments': [
            {'tone': 'great', 'text': '참고 사항입니다.'},
          ],
        }),
      );
      expect(words!.comments.first.tone, InsightTone.info);
    });

    test('조언은 많아야 3개', () {
      final words = AiCoach.parse(
        answer({
          'headline': '요약입니다.',
          'comments': [
            for (int i = 0; i < 5; i++) {'tone': 'info', 'text': '$i번입니다.'},
          ],
        }),
      );
      expect(words!.comments.length, 3);
    });

    test('형식이 틀리면 null (화면은 기본 분석을 씁니다)', () {
      expect(AiCoach.parse(null), isNull);
      expect(AiCoach.parse(''), isNull);
      expect(AiCoach.parse('그냥 문장입니다.'), isNull);
      expect(AiCoach.parse(answer({'headline': '요약입니다.'})), isNull);
      expect(
        AiCoach.parse(
          answer({
            'headline': '',
            'comments': [
              {'tone': 'info', 'text': '내용입니다.'},
            ],
          }),
        ),
        isNull,
      );
    });
  });

  group('어미는 "습니다." 또는 "입니다."만', () {
    test('지키는 문장', () {
      expect(AiCoach.isFormal('4.0km를 달렸습니다.'), isTrue);
      expect(AiCoach.isFormal('지난주의 60% 수준입니다.'), isTrue);
      expect(AiCoach.isFormal('횟수가 줄었습니다. 쉬는 날로 두는 것이 좋습니다.'), isTrue);
      expect(AiCoach.isFormal('부담이 적은 것으로 보입니다'), isTrue);
    });

    test('어기는 문장', () {
      expect(AiCoach.isFormal('꾸준히 달렸어요.'), isFalse);
      expect(AiCoach.isFormal('횟수를 늘리시길 권장합니다.'), isFalse);
      expect(AiCoach.isFormal('기록이 늘었습니다. 계속 달리시겠습니까?'), isFalse);
      expect(AiCoach.isFormal('좋은 흐름이 됩니다.'), isFalse);
      expect(AiCoach.isFormal(''), isFalse);
    });

    test('어긴 조언은 빼고, 한 줄 평이 어기면 통째로 버린다', () {
      final words = AiCoach.parse(
        jsonEncode({
          'headline': '이번 주는 4.0km입니다.',
          'comments': [
            {'tone': 'good', 'text': '3회 달렸습니다.'},
            {'tone': 'info', 'text': '조금 더 뛰어 보세요.'},
          ],
        }),
      );
      expect(words!.comments.length, 1);
      expect(
        AiCoach.parse(
          jsonEncode({
            'headline': '잘 달렸어요.',
            'comments': [
              {'tone': 'good', 'text': '3회 달렸습니다.'},
            ],
          }),
        ),
        isNull,
      );
    });

    test('기본 분석 문장도 전부 이 어미를 지킨다', () {
      for (final double km in [0, 1, 4, 9, 15]) {
        final report = _report(thisWeekKm: km);
        expect(
          AiCoach.isFormal(report.headline),
          isTrue,
          reason: report.headline,
        );
        for (final comment in report.comments) {
          expect(AiCoach.isFormal(comment.text), isTrue, reason: comment.text);
        }
      }
      final empty = RunInsights.analyze(
        range: InsightRange.month,
        statsByKey: const {},
        now: wednesday,
      );
      expect(AiCoach.isFormal(empty.headline), isTrue);
      for (final comment in empty.comments) {
        expect(AiCoach.isFormal(comment.text), isTrue, reason: comment.text);
      }
    });
  });

  test('문장만 바꿔 끼워도 점수는 그대로', () {
    final InsightReport base = _report();
    final InsightReport worded = base.withWords(
      headline: 'AI 요약입니다.',
      comments: const [InsightComment(InsightTone.info, '참고입니다.')],
    );
    expect(worded.writtenByAi, isTrue);
    expect(base.writtenByAi, isFalse);
    expect(worded.score, base.score);
    expect(worded.consistencyScore, base.consistencyScore);
    expect(worded.headline, 'AI 요약입니다.');
  });
}
