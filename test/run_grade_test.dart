import 'package:contact/game/run_grade.dart';
import 'package:contact/game/run_rules.dart';
import 'package:contact/models/run_record.dart';
import 'package:flutter_test/flutter_test.dart';

// km를 분/km 페이스로 쉬지 않고 달린 기록
RunRecord _run(double km, double pace) {
  final Duration time = Duration(seconds: (km * pace * 60).round());
  return RunRecord(
    elapsed: time,
    movingTime: time,
    distanceMeters: km * 1000,
    steps: 0,
    stepsEstimated: false,
  );
}

void main() {
  group('러닝 등급', () {
    test('10km를 6분 페이스로 꾸준히 뛰면 5', () {
      expect(RunGrade.of(_run(10, 6)), 5);
      expect(RunGrade.of(_run(10, 5)), 5);
    });

    test('5km 6분 페이스는 4', () {
      expect(RunGrade.of(_run(5, 6)), 4);
    });

    test('3km 7분 페이스는 3', () {
      expect(RunGrade.of(_run(3, 7)), 3);
    });

    test('가볍게 걸으면 1', () {
      expect(RunGrade.of(_run(3, 12)), 1);
      expect(RunGrade.of(_run(1, 15)), 1);
    });

    test('오래 걸어도 3을 넘지 않는다 (거리만큼 쳐주되 빠르지 않으면)', () {
      expect(RunGrade.of(_run(10, 12)), 3);
    });

    test('아주 빨라도 짧으면 높게 안 나온다', () {
      expect(RunGrade.of(_run(1, 4.5)), lessThanOrEqualTo(2));
    });

    test('안 움직였으면 1', () {
      expect(RunGrade.of(_run(0, 6)), 1);
    });

    test('등급마다 한 줄 평이 있다', () {
      for (int g = 1; g <= 5; g++) {
        expect(RunGrade.verdict(g), isNotEmpty);
      }
    });
  });

  group('페이스가 빠를수록 경험치가 조금 더', () {
    test('걷는 속도면 보너스 없음 (1분당 10)', () {
      // 1km 12분 = 120
      expect(RunRules.expFor(_run(1, 12)), 120);
    });

    test('5분 페이스 이상이면 30% 더', () {
      // 2km 5분 = 10분 -> 100 x 1.3
      expect(RunRules.expFor(_run(2, 5)), 130);
    });

    test('같은 시간이면 빠를수록 더 받는다', () {
      final int slow = RunRules.expFor(_run(2, 10)); // 20분
      final int fast = RunRules.expFor(_run(2.5, 8)); // 20분
      expect(fast, greaterThan(slow));
      // 너무 많이 주지는 않는다
      expect(fast, lessThanOrEqualTo((200 * 1.3).floor()));
    });
  });
}
