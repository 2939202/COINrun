import 'dart:math';

import 'package:contact/game/route_simplifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const double _metersPerLat = 111320;

// 서울 시청에서 북쪽으로 meters만큼 간 지점
LatLng _north(double meters) =>
    LatLng(37.5665 + meters / _metersPerLat, 126.9780);

void main() {
  group('경로 솎아내기', () {
    test('점이 2개 이하면 그대로 둔다', () {
      expect(RouteSimplifier.simplify([]), isEmpty);
      expect(RouteSimplifier.simplify([_north(0)]).length, 1);
      expect(RouteSimplifier.simplify([_north(0), _north(10)]).length, 2);
    });

    test('곧은 길 위의 중간 점들은 버리고 양 끝만 남긴다', () {
      final straight = [for (int i = 0; i <= 100; i++) _north(i * 10)];
      expect(RouteSimplifier.simplify(straight).length, 2);
    });

    test('꺾이는 지점은 남긴다', () {
      // 북쪽으로 100m 갔다가 동쪽으로 꺾어서 100m
      final metersPerLon = _metersPerLat * cos(37.5665 * pi / 180);
      final corner = <LatLng>[
        for (int i = 0; i <= 10; i++) _north(i * 10.0),
        for (int i = 1; i <= 10; i++)
          LatLng(
            37.5665 + 100 / _metersPerLat,
            126.9780 + i * 10 / metersPerLon,
          ),
      ];

      final simplified = RouteSimplifier.simplify(corner);
      expect(simplified.length, 3); // 시작, 꺾이는 곳, 끝
      expect(simplified.first, corner.first);
      expect(simplified.last, corner.last);
    });

    test('시작점과 끝점은 항상 남는다', () {
      final wiggly = [
        for (int i = 0; i < 500; i++)
          LatLng(
            37.5665 + i * 2 / _metersPerLat,
            126.9780 + sin(i / 3) * 30 / _metersPerLat,
          ),
      ];
      final simplified = RouteSimplifier.simplify(wiggly);
      expect(simplified.first, wiggly.first);
      expect(simplified.last, wiggly.last);
    });

    test('아무리 구불구불해도 정해진 개수를 넘지 않는다', () {
      // 1m마다 좌우로 20m씩 흔들리는, 현실에는 없는 최악의 경로
      final worst = [
        for (int i = 0; i < 3000; i++)
          LatLng(
            37.5665 + i / _metersPerLat,
            126.9780 + (i.isEven ? 20 : -20) / _metersPerLat,
          ),
      ];
      final simplified = RouteSimplifier.simplify(worst);
      expect(simplified.length, lessThanOrEqualTo(300));
    });

    test('실제처럼 도는 5km 코스가 크게 줄어든다', () {
      // 400m 트랙을 12바퀴 반 도는 코스를 1초에 한 점씩 받았다고 보고,
      // GPS 흔들림(±3m)까지 섞었습니다. 곧은 구간과 굽은 구간이 함께 있습니다.
      final random = Random(7);
      final metersPerLon = _metersPerLat * cos(37.5665 * pi / 180);
      final realistic = <LatLng>[];
      for (int i = 0; i < 3000; i++) {
        final double angle = i / 3000 * 12.5 * 2 * pi; // 12.5바퀴
        final double x = cos(angle) * 60 + (random.nextDouble() * 6 - 3);
        final double y = sin(angle) * 36 + (random.nextDouble() * 6 - 3);
        realistic.add(
          LatLng(37.5665 + y / _metersPerLat, 126.9780 + x / metersPerLon),
        );
      }

      final simplified = RouteSimplifier.simplify(realistic);
      // ignore: avoid_print
      print('도는 5km 코스: ${realistic.length}점 -> ${simplified.length}점');

      expect(simplified.length, lessThanOrEqualTo(300));
      expect(simplified.length, greaterThan(20)); // 모양이 뭉개질 만큼 줄지는 않음
    });
  });
}
