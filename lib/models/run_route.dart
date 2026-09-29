import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

// ============================================================
// 러닝 한 번의 경로 (Firestore의 users/{userId}/routes/{runId} 문서 한 개)
//
// [왜 러닝 기록과 따로 두나]
//   경로는 기록 하나당 7KB쯤으로, 러닝 기록에서 제일 무거운 부분입니다.
//   그런데 목록 화면이나 주간/월간 집계는 거리·시간·날짜만 쓰고 경로는 보지 않습니다.
//   같은 문서에 넣어두면 목록을 열 때마다 쓰지도 않을 7KB를 60개씩 끌고 오게 됩니다.
//
//   그래서 경로만 따로 두고, 지도를 보여주는 순간에만 읽습니다.
//   문서 이름은 러닝 기록과 같은 id를 씁니다. (runs/abc <-> routes/abc)
//
// [토막으로 나뉘는 이유]
//   신호가 오래 끊긴 구간을 선으로 이어 그리면 실제로 지나지 않은 길이 그려집니다.
//   그래서 끊긴 자리에서 토막을 나눕니다.
//
// [Firestore에 담는 모양]
//   배열 안에 배열을 담지 못하기 때문에, 모든 점을 한 줄로 이어 붙이고
//   새 토막이 시작되는 자리만 pathBreaks에 따로 적어둡니다.
// ============================================================
class RunRoute {
  final List<List<LatLng>> segments;

  const RunRoute(this.segments);

  static const RunRoute empty = RunRoute([]);

  // 지도에 선을 그릴 만한 토막이 하나라도 있는지
  bool get hasPath => segments.any((segment) => segment.length >= 2);

  // 토막을 신경 쓰지 않고 점만 필요할 때 (지도 범위 잡기 등)
  List<LatLng> get points => [for (final segment in segments) ...segment];

  factory RunRoute.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    return RunRoute(_readSegments(map['path'], map['pathBreaks']));
  }

  // 저장할 값을 만듭니다.
  static Map<String, dynamic> toFields(List<List<LatLng>> segments) {
    final List<GeoPoint> points = [];
    final List<int> breaks = [];
    for (final segment in segments) {
      // 첫 토막이 아니면, 이 토막이 시작되는 자리를 적어둡니다.
      if (points.isNotEmpty) breaks.add(points.length);
      for (final point in segment) {
        points.add(GeoPoint(point.latitude, point.longitude));
      }
    }
    return {'path': points, 'pathBreaks': breaks};
  }

  // 경로를 따로 두기 전에는 러닝 기록 문서 안에 같은 모양으로 들어 있었습니다.
  // 그때 저장된 기록도 지도가 보이도록 같은 함수로 읽습니다.
  static List<List<LatLng>> _readSegments(Object? rawPath, Object? rawBreaks) {
    if (rawPath is! List) return const [];
    final List<LatLng> points = rawPath
        .whereType<GeoPoint>()
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    if (points.isEmpty) return const [];

    // 토막을 나누기 전에 저장된 기록에는 pathBreaks가 없습니다. 토막 하나로 봅니다.
    final List<int> breaks = rawBreaks is List
        ? rawBreaks
              .whereType<num>()
              .map((value) => value.toInt())
              .where((index) => index > 0 && index < points.length)
              .toSet()
              .toList()
        : <int>[];
    breaks.sort();

    final List<List<LatLng>> segments = [];
    int start = 0;
    for (final index in [...breaks, points.length]) {
      if (index > start) segments.add(points.sublist(start, index));
      start = index;
    }
    return segments;
  }
}
