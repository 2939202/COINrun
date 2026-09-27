import 'dart:math';

import 'package:latlong2/latlong.dart';

// ============================================================
// 러닝 경로에서 없어도 되는 점을 걸러냅니다 (Douglas-Peucker 방식)
//
// [왜 필요한가]
//   GPS는 1초에 한 번쯤 위치를 주기 때문에 5km를 뛰면 점이 3,000개쯤 쌓입니다.
//   그대로 저장하면 기록 하나가 150KB가 넘고, 대부분은 곧은 길 위에 늘어선
//   "굳이 없어도 선 모양이 똑같은" 점들입니다.
//
// [어떻게 걸러내나]
//   시작점과 끝점을 직선으로 이어놓고, 그 직선에서 가장 멀리 떨어진 점을 찾습니다.
//   그 거리가 기준(tolerance)보다 가까우면 사이의 점들은 전부 버립니다.
//   멀면 그 점을 남기고, 그 점을 기준으로 둘로 나눠서 같은 일을 반복합니다.
//   결과적으로 코너처럼 모양을 만드는 점만 남습니다.
// ============================================================
class RouteSimplifier {
  RouteSimplifier._();

  // 이 거리(m)보다 직선에 가까운 점은 버립니다. 5m면 지도에서 차이가 보이지 않습니다.
  static const double defaultToleranceMeters = 5;

  // 아무리 복잡한 경로여도 이 개수를 넘지 않게 합니다.
  static const int defaultMaxPoints = 300;

  // 토막마다 따로 걸러냅니다. 토막을 합쳐서 걸러내면 끊긴 구간이 이어져 버립니다.
  // 점이 하나뿐인 토막(끊긴 직후)은 선을 그릴 수 없어서 버립니다.
  static List<List<LatLng>> simplifySegments(
    List<List<LatLng>> segments, {
    double tolerance = defaultToleranceMeters,
    int maxPoints = defaultMaxPoints,
  }) {
    return [
      for (final segment in segments)
        if (segment.length >= 2)
          simplify(segment, tolerance: tolerance, maxPoints: maxPoints),
    ];
  }

  static List<LatLng> simplify(
    List<LatLng> points, {
    double tolerance = defaultToleranceMeters,
    int maxPoints = defaultMaxPoints,
  }) {
    if (points.length <= 2) return List<LatLng>.from(points);

    List<LatLng> result = _douglasPeucker(points, tolerance);

    // 그래도 많으면 기준을 두 배씩 느슨하게 해서 다시 걸러냅니다.
    // (아주 구불구불한 길에서도 저장 크기가 무한정 늘지 않도록)
    double current = tolerance;
    while (result.length > maxPoints && current < 1000) {
      current *= 2;
      result = _douglasPeucker(points, current);
    }
    return result;
  }

  static List<LatLng> _douglasPeucker(List<LatLng> points, double tolerance) {
    // 남길 점에 표시를 합니다. 재귀 대신 직접 만든 스택을 쓰는 이유는,
    // 점이 수천 개일 때 재귀가 너무 깊어져 앱이 멈추는 것을 막기 위해서입니다.
    final List<bool> keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    final List<List<int>> stack = [
      [0, points.length - 1],
    ];

    while (stack.isNotEmpty) {
      final List<int> range = stack.removeLast();
      final int first = range[0];
      final int last = range[1];
      if (last <= first + 1) continue;

      double worst = 0;
      int worstIndex = first;
      for (int i = first + 1; i < last; i++) {
        final double distance = _distanceToLine(
          points[i],
          points[first],
          points[last],
        );
        if (distance > worst) {
          worst = distance;
          worstIndex = i;
        }
      }

      if (worst > tolerance) {
        keep[worstIndex] = true;
        stack.add([first, worstIndex]);
        stack.add([worstIndex, last]);
      }
    }

    final List<LatLng> result = [];
    for (int i = 0; i < points.length; i++) {
      if (keep[i]) result.add(points[i]);
    }
    return result;
  }

  // 점 p가 선분 a~b에서 얼마나 떨어져 있는지(m)
  //
  // 위도/경도를 미터로 바꿔 평면처럼 계산합니다. 지구는 둥글지만 러닝 한 번의
  // 범위(수 km)에서는 이 방식의 오차가 눈에 띄지 않습니다.
  static double _distanceToLine(LatLng p, LatLng a, LatLng b) {
    const double metersPerLat = 111320;
    final double metersPerLon = metersPerLat * cos(a.latitude * pi / 180);

    final double px = (p.longitude - a.longitude) * metersPerLon;
    final double py = (p.latitude - a.latitude) * metersPerLat;
    final double bx = (b.longitude - a.longitude) * metersPerLon;
    final double by = (b.latitude - a.latitude) * metersPerLat;

    final double lengthSquared = bx * bx + by * by;
    // a와 b가 같은 자리면 그냥 두 점 사이 거리입니다.
    if (lengthSquared == 0) return sqrt(px * px + py * py);

    // 선분 위에서 p와 가장 가까운 지점의 위치(0=a, 1=b). 선분 밖으로 나가지 않게 자릅니다.
    final double t = ((px * bx + py * by) / lengthSquared).clamp(0.0, 1.0);
    final double dx = px - bx * t;
    final double dy = py - by * t;
    return sqrt(dx * dx + dy * dy);
  }
}
