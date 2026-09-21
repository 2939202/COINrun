import 'package:contact/game/run_rules.dart';
import 'package:contact/models/run_record.dart';
import 'package:contact/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RunRules', () {
    test('100m마다 10골드 + 50EXP, 남은 거리는 버림', () {
      const run = RunRecord(elapsed: Duration(minutes: 2), distanceMeters: 250);
      expect(RunRules.goldFor(run), 20);
      expect(RunRules.expFor(run), 100);
    });

    test('레벨업 시 초과 경험치는 이월되고, 여러 레벨이 한 번에 오를 수 있음', () {
      expect(RunRules.addExp(1, 0, 50), (level: 1, exp: 50));
      expect(RunRules.addExp(1, 80, 50), (level: 2, exp: 30));
      // Lv1(100) + Lv2(200) = 300을 넘겨서 Lv3, 남은 50
      expect(RunRules.addExp(1, 0, 350), (level: 3, exp: 50));
    });
  });

  group('formatters', () {
    test('시간', () {
      expect(formatDuration(const Duration(seconds: 65)), '01:05');
      expect(formatDuration(const Duration(hours: 1, seconds: 5)), '01:00:05');
    });

    test('페이스', () {
      expect(formatPace(6.5), "6'30\"");
      expect(formatPace(5.999), "6'00\"");
      expect(formatPace(null), "-'--\"");
    });

    test('거리가 거의 없으면 페이스를 계산하지 않음', () {
      const run = RunRecord(elapsed: Duration(minutes: 1), distanceMeters: 3);
      expect(run.paceMinPerKm, isNull);
    });
  });
}
