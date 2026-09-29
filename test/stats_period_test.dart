import 'package:contact/game/stats_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('주간 칸 이름', () {
    // 2026-09-28은 월요일입니다.
    test('월요일은 그 자신이 주의 시작', () {
      final monday = DateTime(2026, 9, 28, 14, 30);
      expect(StatsPeriod.weekStart(monday), DateTime(2026, 9, 28));
      expect(StatsPeriod.weekKey(monday), 'w2026-09-28');
    });

    test('같은 주의 다른 요일도 같은 칸으로 간다', () {
      for (int day = 28; day <= 30; day++) {
        expect(StatsPeriod.weekKey(DateTime(2026, 9, day)), 'w2026-09-28');
      }
      for (int day = 1; day <= 4; day++) {
        expect(StatsPeriod.weekKey(DateTime(2026, 10, day)), 'w2026-09-28');
      }
    });

    test('일요일은 그 주의 마지막날이지 다음 주가 아니다', () {
      // 2026-10-04는 일요일
      expect(StatsPeriod.weekKey(DateTime(2026, 10, 4)), 'w2026-09-28');
      // 다음날 월요일부터 새 칸
      expect(StatsPeriod.weekKey(DateTime(2026, 10, 5)), 'w2026-10-05');
    });

    test('시각은 버리고 날짜만 본다', () {
      expect(
        StatsPeriod.weekKey(DateTime(2026, 9, 30, 23, 59, 59)),
        StatsPeriod.weekKey(DateTime(2026, 9, 30, 0, 0, 1)),
      );
    });

    // 주 번호(ISO week) 대신 월요일 날짜를 쓰는 이유가 여기 있습니다.
    // 연말연시에도 헷갈릴 일이 없습니다.
    test('연말에 걸친 주도 한 칸으로 묶인다', () {
      // 2026-12-28(월) ~ 2027-01-03(일)
      expect(StatsPeriod.weekKey(DateTime(2026, 12, 31)), 'w2026-12-28');
      expect(StatsPeriod.weekKey(DateTime(2027, 1, 1)), 'w2026-12-28');
      expect(StatsPeriod.weekKey(DateTime(2027, 1, 3)), 'w2026-12-28');
      expect(StatsPeriod.weekKey(DateTime(2027, 1, 4)), 'w2027-01-04');
    });
  });

  group('월간 칸 이름', () {
    test('같은 달이면 같은 칸', () {
      expect(StatsPeriod.monthKey(DateTime(2026, 9, 1)), 'm2026-09');
      expect(StatsPeriod.monthKey(DateTime(2026, 9, 30, 23, 59)), 'm2026-09');
    });

    test('달이 바뀌면 칸도 바뀐다', () {
      expect(StatsPeriod.monthKey(DateTime(2026, 10, 1)), 'm2026-10');
    });

    test('한 자리 달도 두 자리로 적는다 (이름순이 곧 시간순)', () {
      expect(StatsPeriod.monthKey(DateTime(2026, 3, 15)), 'm2026-03');
      final keys = [
        StatsPeriod.monthKey(DateTime(2026, 3, 1)),
        StatsPeriod.monthKey(DateTime(2026, 10, 1)),
      ]..sort();
      expect(keys, ['m2026-03', 'm2026-10']);
    });

    test('월의 시작은 1일 0시', () {
      expect(
        StatsPeriod.monthStart(DateTime(2026, 9, 27, 18)),
        DateTime(2026, 9, 1),
      );
    });
  });

  group('주간과 월간은 서로 섞이지 않는다', () {
    test('이름 앞글자로 구분된다', () {
      final week = StatsPeriod.weekKey(DateTime(2026, 9, 28));
      final month = StatsPeriod.monthKey(DateTime(2026, 9, 28));
      expect(week.startsWith('w'), isTrue);
      expect(month.startsWith('m'), isTrue);
      expect(week, isNot(month));
    });
  });
}
