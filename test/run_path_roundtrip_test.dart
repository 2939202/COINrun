import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contact/game/route_simplifier.dart';
import 'package:contact/game/run_tracker.dart';
import 'package:contact/models/run_route.dart';
import 'package:contact/models/run_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const double _metersPerLat = 111320;

LatLng _north(double meters) =>
    LatLng(37.5665 + meters / _metersPerLat, 126.9780);

// 실제로 뛰었을 때 일어나는 일을 처음부터 끝까지 따라갑니다.
//   러닝 화면(RunTracker) -> 저장(RouteSimplifier + pathFields)
//   -> Firestore -> 읽기(RunLog.fromMap) -> 기록 상세 화면
//
// 중간 어디가 끊겨도 화면에서는 똑같이 "경로가 안 보인다"로만 보이기 때문에,
// 단계마다 끊어서 확인합니다.
void main() {
  final DateTime t0 = DateTime(2026, 9, 27, 7);

  // Firestore에 썼다가 다시 읽어오는 것을 흉내냅니다.
  // Firestore의 routes/{runId} 문서에 썼다가 다시 읽어오는 것을 흉내냅니다.
  RunRoute saveAndLoad(RunRecord record) {
    final saved = RunRoute.toFields(
      RouteSimplifier.simplifySegments(record.segments),
    );
    return RunRoute.fromMap(saved);
  }

  // 밖에서 200m쯤 곧게 뛴 경우. 가장 흔한 상황입니다.
  RunTracker straightRun() {
    final tracker = RunTracker()..start(_north(0), t0);
    for (int i = 1; i <= 20; i++) {
      tracker.addPosition(_north(i * 10), t0.add(Duration(seconds: i * 5)));
    }
    return tracker;
  }

  group('경로가 화면까지 살아서 도착하는지', () {
    test('1. 트래커에 점이 쌓인다', () {
      final record = straightRun().record;
      expect(record.segments.length, 1);
      expect(record.segments.first.length, 21);
      expect(record.path.length, 21);
    });

    test('2. 솎아내도 선을 그릴 점은 남는다', () {
      final simplified = RouteSimplifier.simplifySegments(
        straightRun().record.segments,
      );
      expect(simplified.length, 1);
      expect(simplified.first.length, greaterThanOrEqualTo(2));
    });

    test('3. 저장했다 읽으면 그대로 돌아온다', () {
      final route = saveAndLoad(straightRun().record);
      expect(route.hasPath, isTrue);
      expect(route.segments.length, 1);
      expect(route.segments.first.length, greaterThanOrEqualTo(2));
    });

    test('4. 출발점과 도착점이 유지된다', () {
      final record = straightRun().record;
      final route = saveAndLoad(record);
      expect(
        route.points.first.latitude,
        closeTo(record.path.first.latitude, 1e-9),
      );
      expect(
        route.points.last.latitude,
        closeTo(record.path.last.latitude, 1e-9),
      );
    });
  });

  group('모퉁이를 도는 경로', () {
    test('코너가 살아남는다', () {
      final metersPerLon = _metersPerLat * cos(37.5665 * pi / 180);
      final tracker = RunTracker()..start(_north(0), t0);
      int second = 0;
      for (int i = 1; i <= 10; i++) {
        tracker.addPosition(
          _north(i * 10.0),
          t0.add(Duration(seconds: ++second * 5)),
        );
      }
      for (int i = 1; i <= 10; i++) {
        tracker.addPosition(
          LatLng(
            37.5665 + 100 / _metersPerLat,
            126.9780 + i * 10 / metersPerLon,
          ),
          t0.add(Duration(seconds: ++second * 5)),
        );
      }

      final route = saveAndLoad(tracker.record);
      expect(route.hasPath, isTrue);
      // 시작 / 코너 / 끝 세 점은 남아야 모양이 유지됩니다.
      expect(route.segments.first.length, greaterThanOrEqualTo(3));
    });
  });

  group('신호가 끊긴 경로', () {
    test('끊긴 앞뒤가 모두 살아남고 토막으로 나뉜다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      for (int i = 1; i <= 10; i++) {
        tracker.addPosition(_north(i * 10.0), t0.add(Duration(seconds: i * 5)));
      }
      // 5분 끊긴 뒤 멀리서 다시 잡힘
      tracker.addPosition(_north(5000), t0.add(const Duration(minutes: 5)));
      for (int i = 1; i <= 10; i++) {
        tracker.addPosition(
          _north(5000 + i * 10.0),
          t0.add(Duration(minutes: 5, seconds: i * 5)),
        );
      }

      final route = saveAndLoad(tracker.record);
      expect(route.segments.length, 2);
      expect(route.segments[0].length, greaterThanOrEqualTo(2));
      expect(route.segments[1].length, greaterThanOrEqualTo(2));
      expect(route.hasPath, isTrue);
    });
  });

  group('짧은 러닝', () {
    // 몇 걸음만 뛰고 완료를 눌러도 선은 그려져야 합니다.
    test('점 두 개짜리도 살아남는다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      tracker.addPosition(_north(10), t0.add(const Duration(seconds: 5)));

      final route = saveAndLoad(tracker.record);
      expect(route.hasPath, isTrue);
      expect(route.segments.first.length, 2);
    });

    // 시작하자마자 완료를 누른 경우. 그릴 게 없다고 제대로 말해야 합니다.
    test('점 하나뿐이면 경로 없음으로 본다', () {
      final tracker = RunTracker()..start(_north(0), t0);
      final route = saveAndLoad(tracker.record);
      expect(route.hasPath, isFalse);
    });
  });

  group('Firestore가 실제로 돌려주는 모양', () {
    test('GeoPoint 목록과 pathBreaks로 저장된다', () {
      final saved = RunRoute.toFields(
        RouteSimplifier.simplifySegments(straightRun().record.segments),
      );
      expect(saved['path'], isA<List<GeoPoint>>());
      expect(saved['pathBreaks'], isA<List<int>>());
      expect((saved['path'] as List).isNotEmpty, isTrue);
    });
  });
}
