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

// 북쪽으로 정확히 몇 m (흔들림처럼 작은 거리를 다룰 때)
LatLng _northMeters(double meters) =>
    LatLng(37.5665 + meters / 111320, 126.9780);

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

    // 안드로이드 걸음 센서는 구독하는 순간 "폰 켠 뒤 누적 걸음 수"를 한 번 뱉습니다.
    // 그 값만 받고 이후 새 걸음이 없으면(= 시뮬레이터로 위치만 움직이는 상황)
    // 걸음 수가 0에서 멈춰 골드가 쌓이지 않았습니다.
    test('센서 값을 한 번만 받고 새 걸음이 없으면 걸음 수가 0이다', () {
      final tracker = RunTracker()
        ..addSensorSteps(12345) // 화면에 들어가자마자 들어오는 누적값
        ..start(_north(0), t0);
      tracker.addPosition(_north(10), t0.add(const Duration(seconds: 50)));

      expect(tracker.record.distanceMeters, greaterThan(100));
      expect(tracker.record.steps, 0);
      expect(tracker.record.stepsEstimated, isFalse);
    });

    // 조이스틱 모드에서 골드가 거리만 보고 오르는지 확인합니다.
    // run_screen이 하는 일과 같은 순서: 센서값 한 번 수신 -> 시작 -> 조이스틱 켜기 -> 5m씩 이동
    // 2초마다 위치가 들어오므로, 가만히 있을 때 흔들림이 거리로 쌓이면 안 됩니다.
    test('제자리 흔들림은 거리에 쌓이지 않는다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      // 1~2m 안에서 30번 흔들림 (2초 간격 = 1분)
      for (int i = 1; i <= 30; i++) {
        tracker.addPosition(
          _northMeters(i.isEven ? 1.5 : -1.5),
          t0.add(Duration(seconds: i * 2)),
        );
      }
      expect(tracker.record.distanceMeters, 0);
      expect(tracker.record.movingTime, Duration.zero);
      expect(tracker.segments.first.length, 1); // 점이 안 늘어남
    });

    // 흔들림을 거를 때 기준점까지 옮겨버리면, 천천히 걷는 사람은 매번 기준 미만이라
    // 영영 거리가 쌓이지 않습니다. 기준점을 그대로 둬야 넘는 순간 잡힙니다.
    test('천천히 걸어도 기준을 넘는 순간 거리가 쌓인다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      // 2초마다 1.2m씩 앞으로 (시속 2.2km, 아주 느린 걸음)
      for (int i = 1; i <= 10; i++) {
        tracker.addPosition(
          _northMeters(i * 1.2),
          t0.add(Duration(seconds: i * 2)),
        );
      }
      // 12m를 갔으니 그만큼 쌓여야 합니다. (3m 단위로 끊겨서 잡힘)
      expect(tracker.record.distanceMeters, greaterThan(8));
      expect(tracker.record.distanceMeters, lessThanOrEqualTo(12.1));
    });

    // GPS를 못 잡은 채로 시작을 누르면 예전에는 기본 좌표(서울 시청)가 출발점이 됐습니다.
    // 그러면 첫 위치가 들어올 때 거기까지가 한 번에 뛴 것으로 계산돼 통째로 버려졌습니다.
    test('GPS를 못 잡은 채로 시작하면 첫 위치가 출발점이 된다', () {
      final tracker = RunTracker()..start(null, t0);
      expect(tracker.segments, isEmpty);

      // 첫 위치 - 어디든 출발점으로 삼습니다.
      tracker.addPosition(_north(0), t0.add(const Duration(seconds: 3)));
      expect(tracker.segments.length, 1);
      expect(tracker.record.distanceMeters, 0);
      expect(tracker.rejectedJumps, 0);

      // 그다음부터는 정상으로 쌓입니다.
      tracker.addPosition(_north(1), t0.add(const Duration(seconds: 8)));
      expect(tracker.record.distanceMeters, closeTo(11.1, 0.5));
      expect(tracker.segments.first.length, 2);
    });

    // 화면을 끄고 몇 분 지나면 위치 전달이 끊깁니다. 앱으로 돌아올 때 들어오는
    // 첫 위치는 멀찍이 떨어져 있는데, 그 직선은 실제로 지나온 길이 아닙니다.
    test('신호가 끊겼다 돌아온 먼 점프는 거리에 더하지 않는다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      tracker.addPosition(_north(1), t0.add(const Duration(seconds: 5)));
      final double before = tracker.record.distanceMeters;

      // 5분 뒤 1km 떨어진 곳에서 돌아옴
      tracker.addPosition(_north(90), t0.add(const Duration(minutes: 5)));

      expect(tracker.record.distanceMeters, before);
      expect(before, closeTo(11.1, 0.5));
    });

    test('먼 점프는 경로를 끊어서 새 토막으로 시작한다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      tracker.addPosition(_north(1), t0.add(const Duration(seconds: 5)));
      expect(tracker.segments.length, 1);

      tracker.addPosition(_north(90), t0.add(const Duration(minutes: 5)));
      expect(tracker.segments.length, 2);

      // 돌아온 자리에서 이어 뛴 것은 새 토막에 정상으로 쌓입니다.
      tracker.addPosition(
        _north(91),
        t0.add(const Duration(minutes: 5, seconds: 5)),
      );
      expect(tracker.segments.last.length, 2);
      expect(tracker.record.distanceMeters, closeTo(22.2, 1));
    });

    test('가까운 점프는 원래대로 거리에 더한다 (신호가 잠깐만 끊긴 경우)', () {
      final tracker = RunTracker()..start(_north(0), t0);
      // 150m 떨어진 점 - 기준(200m) 안쪽이라 그대로 인정
      tracker.addPosition(_north(14), t0.add(const Duration(seconds: 40)));

      expect(tracker.record.distanceMeters, closeTo(155.8, 2));
      expect(tracker.segments.length, 1);
    });

    test('일시정지했다 재개하면 그 사이를 선으로 잇지 않는다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      tracker.addPosition(_north(1), t0.add(const Duration(seconds: 5)));
      tracker.pause();
      tracker.resume(t0.add(const Duration(minutes: 3)));
      tracker.addPosition(
        _north(2),
        t0.add(const Duration(minutes: 3, seconds: 5)),
      );

      expect(tracker.segments.length, 2);
    });

    test('조이스틱 모드에서는 골드가 거리로 오른다 (7.5m당 1골드)', () {
      const double metersPerDegreeLat = 111320;
      LatLng at(int taps) =>
          LatLng(37.5665 + taps * 5 / metersPerDegreeLat, 126.9780);

      final tracker = RunTracker()
        ..addSensorSteps(12345) // 화면을 열자마자 센서가 뱉는 누적값
        ..start(at(0), t0);
      // 조이스틱 켜기 (러닝 화면이 하는 것과 똑같이 두 가지를 끕니다)
      tracker.disableStepSensor();
      tracker.enforceSpeedLimit = false; // 0.15초에 5m = 33m/s라 제한에 걸립니다

      for (int taps = 1; taps <= 20; taps++) {
        tracker.addPosition(
          at(taps),
          t0.add(Duration(milliseconds: 150 * taps)),
        );
      }

      final record = tracker.record;
      expect(record.distanceMeters, closeTo(100, 1)); // 5m x 20번
      expect(record.steps, 133); // 100m / 0.75m
      expect(RunRules.goldFor(record), 13); // 133걸음 / 10
    });

    test('센서를 끄면 다시 거리로 걸음 수를 추정한다 (시뮬레이터용)', () {
      final tracker = RunTracker()
        ..addSensorSteps(12345)
        ..start(_north(0), t0);
      tracker.addPosition(_north(10), t0.add(const Duration(seconds: 50)));
      expect(tracker.record.steps, 0);

      tracker.disableStepSensor();

      expect(tracker.record.stepsEstimated, isTrue);
      expect(
        tracker.record.steps,
        (tracker.record.distanceMeters / 0.75).floor(),
      );
      expect(tracker.record.steps, greaterThan(0));
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
