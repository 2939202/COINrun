import 'package:contact/game/run_rules.dart';
import 'package:contact/game/run_tracker.dart';
import 'package:contact/models/run_record.dart';
import 'package:contact/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

RunRecord _record({
  Duration movingTime = Duration.zero,
  double distance = 0,
  int steps = 0,
}) => RunRecord(
  elapsed: movingTime,
  movingTime: movingTime,
  distanceMeters: distance,
  steps: steps,
  stepsEstimated: false,
);

// 위도 0.0001도 = 약 11m (북쪽으로 이동)
LatLng _north(int step) => LatLng(37.5665 + step * 0.0001, 126.9780);

void main() {
  group('RunRules', () {
    test('움직인 시간 1분당 10 EXP', () {
      expect(
        RunRules.expFor(_record(movingTime: const Duration(minutes: 10))),
        100,
      );
      expect(
        RunRules.expFor(_record(movingTime: const Duration(seconds: 90))),
        15,
      );
    });

    test('10걸음당 1골드, 남는 걸음은 버림', () {
      expect(RunRules.goldFor(_record(steps: 6000)), 600);
      expect(RunRules.goldFor(_record(steps: 19)), 1);
    });

    test('레벨업 시 초과 경험치는 이월되고, 여러 레벨이 한 번에 오를 수 있음', () {
      expect(RunRules.addExp(1, 0, 50), (level: 1, exp: 50));
      expect(RunRules.addExp(1, 80, 50), (level: 2, exp: 30));
      // Lv1(100) + Lv2(200) = 300을 넘겨서 Lv3, 남은 50
      expect(RunRules.addExp(1, 0, 350), (level: 3, exp: 50));
    });
  });

  group('RunTracker', () {
    final DateTime t0 = DateTime(2026, 9, 21, 7);

    test('걷는 속도 이상으로 움직인 시간만 센다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      // 5초마다 11m (시속 약 8km) -> 움직임
      for (int i = 1; i <= 6; i++) {
        tracker.addPosition(_north(i), t0.add(Duration(seconds: 5 * i)));
      }
      expect(tracker.record.movingTime, const Duration(seconds: 30));
      expect(tracker.record.distanceMeters, closeTo(66.7, 1));
    });

    test('가만히 서 있거나(느린 GPS 흔들림) 신호가 오래 끊긴 시간은 세지 않는다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      // 60초 동안 11m -> 0.18m/s, 걷는 속도 미만
      tracker.addPosition(_north(1), t0.add(const Duration(seconds: 60)));
      expect(tracker.record.movingTime, Duration.zero);
    });

    test('일시정지 중 이동은 거리/시간/걸음에 포함되지 않는다', () {
      final tracker = RunTracker()
        ..addSensorSteps(1000)
        ..start(_north(0), t0);
      tracker.addSensorSteps(1100); // 100걸음
      tracker.pause();
      tracker.addSensorSteps(1500); // 일시정지 중 400걸음 -> 제외
      tracker.addPosition(_north(50), t0.add(const Duration(seconds: 30)));
      tracker.resume(t0.add(const Duration(seconds: 60)));
      tracker.addSensorSteps(1550); // 50걸음
      tracker.addPosition(_north(51), t0.add(const Duration(seconds: 65)));

      expect(tracker.record.steps, 150);
      expect(tracker.record.distanceMeters, closeTo(11.1, 0.5));
      expect(tracker.record.movingTime, const Duration(seconds: 5));
    });

    test('걸음 센서가 없으면 거리로 걸음 수를 추정한다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      tracker.addPosition(_north(10), t0.add(const Duration(seconds: 50)));
      expect(tracker.record.stepsEstimated, isTrue);
      expect(
        tracker.record.steps,
        (tracker.record.distanceMeters / 0.75).floor(),
      );
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
      expect(_record(distance: 3).paceMinPerKm, isNull);
    });
  });
}
