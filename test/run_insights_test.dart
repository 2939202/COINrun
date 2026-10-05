import 'package:contact/game/run_insights.dart';
import 'package:contact/models/run_stats.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-10-07 수요일 정오. 이번 주는 10/5(월)에 시작했습니다.
final DateTime wednesday = DateTime(2026, 10, 7, 12);

RunStats week(String key, {int runs = 2, double km = 6, int movingMin = 36}) =>
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

Map<String, RunStats> weeks(List<RunStats> list) => {
  for (final w in list) w.key: w,
};

void main() {
  group('기간 이름', () {
    test('주간은 이번 주 포함 6주, 오래된 것부터', () {
      final keys = RunInsights.keysFor(InsightRange.week, wednesday);
      expect(keys.length, 6);
      expect(keys.first, 'w2026-08-31');
      expect(keys.last, 'w2026-10-05');
    });

    test('월간은 해를 넘어가도 이어진다', () {
      final keys = RunInsights.keysFor(
        InsightRange.month,
        DateTime(2027, 2, 3),
      );
      expect(keys, [
        'm2026-09',
        'm2026-10',
        'm2026-11',
        'm2026-12',
        'm2027-01',
        'm2027-02',
      ]);
    });

    test('수요일 정오면 이번 주가 약 36% 지났다', () {
      final double p = RunInsights.progressOf(InsightRange.week, wednesday);
      expect(p, closeTo(2.5 / 7, 0.001));
    });
  });

  group('점수', () {
    test('기록이 없으면 0점, 분석할 기록이 없다고 말한다', () {
      final report = RunInsights.analyze(
        range: InsightRange.week,
        statsByKey: const {},
        now: wednesday,
      );
      expect(report.score, 0);
      expect(report.hasAnyRun, isFalse);
      expect(report.headline, '아직 분석할 기록이 없습니다.');
      expect(report.comments, isNotEmpty);
    });

    test('4주 내내 목표 이상 뛰고 이번 주도 잘 뛰면 만점', () {
      final report = RunInsights.analyze(
        range: InsightRange.week,
        statsByKey: weeks([
          week('w2026-09-07', km: 12),
          week('w2026-09-14', km: 12),
          week('w2026-09-21', km: 12),
          week('w2026-09-28', km: 12),
          week('w2026-10-05', km: 8), // 수요일인데 벌써 8km -> 예상 22km
        ]),
        now: wednesday,
      );
      expect(report.consistencyScore, 40);
      expect(report.volumeScore, 30);
      expect(report.trendScore, 30);
      expect(report.score, 100);
    });

    test('지난 4주 중 2주만 뛰면 꾸준함은 절반', () {
      final report = RunInsights.analyze(
        range: InsightRange.week,
        statsByKey: weeks([week('w2026-09-14'), week('w2026-09-28')]),
        now: wednesday,
      );
      expect(report.consistencyScore, 20);
    });

    // 진행 중인 주를 그대로 비교하면 늘 줄어든 것처럼 보입니다.
    test('이번 주는 지금 속도로 끝까지 갔을 때로 비교한다', () {
      final report = RunInsights.analyze(
        range: InsightRange.week,
        statsByKey: weeks([
          week('w2026-09-28', km: 10),
          week('w2026-10-05', km: 4), // 36% 지난 시점의 4km -> 예상 약 11km
        ]),
        now: wednesday,
      );
      expect(report.projectedKm, closeTo(11.2, 0.1));
      expect(report.trendScore, greaterThan(15)); // 지난주보다 늘어남
    });

    test('점수는 0~100 사이', () {
      final report = RunInsights.analyze(
        range: InsightRange.month,
        statsByKey: {'m2026-10': week('m2026-10', runs: 30, km: 500)},
        now: wednesday,
      );
      expect(report.score, inInclusiveRange(0, 100));
    });
  });

  group('조언', () {
    test('갑자기 많이 늘리면 무리하지 말라고 한다', () {
      final report = RunInsights.analyze(
        range: InsightRange.week,
        statsByKey: weeks([
          week('w2026-09-28', km: 5),
          week('w2026-10-05', km: 6), // 예상 약 17km = 지난주의 3배
        ]),
        now: wednesday,
      );
      expect(
        report.comments.any(
          (c) => c.tone == InsightTone.warn && c.text.contains('부담'),
        ),
        isTrue,
      );
    });

    test('페이스가 빨라지면 칭찬한다', () {
      final report = RunInsights.analyze(
        range: InsightRange.week,
        statsByKey: weeks([
          week('w2026-09-28', km: 5, movingMin: 35), // 7'00"
          week('w2026-10-05', km: 5, movingMin: 30), // 6'00"
        ]),
        now: wednesday,
      );
      expect(report.comments.any((c) => c.text.contains('60초 빠르게')), isTrue);
    });

    test('이번 주에 안 뛰었으면 시작을 권한다', () {
      final report = RunInsights.analyze(
        range: InsightRange.week,
        statsByKey: weeks([week('w2026-09-28')]),
        now: wednesday,
      );
      expect(report.headline, '이번 주는 아직 기록이 없습니다.');
    });
  });
}
