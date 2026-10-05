import 'package:contact/game/run_rules.dart';
import 'package:contact/game/run_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const double _metersPerLat = 111320;

LatLng _north(double meters) =>
    LatLng(37.5665 + meters / _metersPerLat, 126.9780);

// 너무 빠른 이동(차, 빠른 자전거)은 달린 것으로 치지 않습니다. (RunTracker.maxRunningSpeed)
void main() {
  final DateTime t0 = DateTime(2026, 10, 5, 7);

  // 2초마다 metersPerTick씩 북쪽으로 count번 움직입니다.
  RunTracker move({
    required double metersPerTick,
    int count = 30,
    bool enforce = true,
  }) {
    final tracker = RunTracker()
      ..enforceSpeedLimit = enforce
      ..start(_north(0), t0);
    for (int i = 1; i <= count; i++) {
      tracker.addPosition(
        _north(i * metersPerTick),
        t0.add(Duration(seconds: i * 2)),
      );
    }
    return tracker;
  }

  test('빠른 러너(시속 18km, 5m/s)는 그대로 기록된다', () {
    final tracker = move(metersPerTick: 10);
    expect(tracker.record.distanceMeters, closeTo(300, 2));
    expect(tracker.record.movingTime, const Duration(seconds: 60));
    expect(tracker.tooFastCount, 0);
    expect(tracker.lastWasTooFast, isFalse);
  });

  test('차(시속 50km, 약 14m/s)로 이동하면 거리·움직인 시간이 쌓이지 않는다', () {
    final tracker = move(metersPerTick: 28);
    expect(tracker.record.distanceMeters, 0);
    expect(tracker.record.movingTime, Duration.zero);
    expect(tracker.tooFastCount, 30);
    expect(tracker.tooFastMeters, closeTo(840, 5));
    expect(tracker.lastWasTooFast, isTrue);
  });

  // 걸음 센서가 없으면 걸음을 거리로 추정합니다. 뺀 거리는 골드에도 들어가지 않아야 합니다.
  test('걸음 센서가 없는 폰에서 차로 이동해도 골드·경험치가 0', () {
    final record = move(metersPerTick: 28).record;
    expect(record.stepsEstimated, isTrue);
    expect(record.steps, 0);
    expect(RunRules.goldFor(record), 0);
    expect(RunRules.expFor(record), 0);
  });

  test('경계값: 7m/s까지는 인정하고 넘으면 뺀다', () {
    expect(
      move(metersPerTick: 14, count: 1).record.distanceMeters,
      closeTo(14, 0.5),
    );
    expect(move(metersPerTick: 15, count: 1).record.distanceMeters, 0);
  });

  test('달리다 차를 타면 달린 구간만 남고, 차로 간 길은 지도에 잇지 않는다', () {
    final tracker = RunTracker()..start(_north(0), t0);
    // 1분 달리기 (5m/s)
    for (int i = 1; i <= 30; i++) {
      tracker.addPosition(_north(i * 10), t0.add(Duration(seconds: i * 2)));
    }
    // 이어서 20초 차 (15m/s)
    for (int i = 1; i <= 10; i++) {
      tracker.addPosition(
        _north(300 + i * 30),
        t0.add(Duration(seconds: 60 + i * 2)),
      );
    }
    // 내려서 다시 1분 달리기
    for (int i = 1; i <= 30; i++) {
      tracker.addPosition(
        _north(600 + i * 10),
        t0.add(Duration(seconds: 80 + i * 2)),
      );
    }

    expect(tracker.record.distanceMeters, closeTo(600, 3));
    expect(tracker.record.movingTime, const Duration(seconds: 120));
    expect(tracker.lastWasTooFast, isFalse); // 마지막은 다시 달리는 중
    // 처음 달린 토막과 내린 뒤 달린 토막이 따로입니다.
    final long = tracker.segments.where((s) => s.length > 2).toList();
    expect(long.length, 2);
  });

  test('개발자 모드 조이스틱(제한 꺼짐)은 빨라도 기록된다', () {
    final tracker = move(metersPerTick: 28, enforce: false);
    expect(tracker.record.distanceMeters, closeTo(840, 5));
    expect(tracker.tooFastCount, 0);
  });

  test('새로 시작하면 빨라서 뺀 기록도 0으로 돌아간다', () {
    final tracker = move(metersPerTick: 28);
    tracker.start(_north(0), t0.add(const Duration(hours: 1)));
    expect(tracker.tooFastCount, 0);
    expect(tracker.tooFastMeters, 0);
    expect(tracker.lastWasTooFast, isFalse);
  });
}
