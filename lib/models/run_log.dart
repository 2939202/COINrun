import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

// Firestore의 users/{userId}/runs/{runId} 문서 - 저장된 러닝 기록 한 개
class RunLog {
  final double distanceMeters;
  final int durationSeconds;
  final int goldEarned;
  final int expEarned;
  final DateTime? createdAt; // 저장 직후 잠깐은 서버 시간이 아직 없어서 null일 수 있음

  // 지나온 길. 경로를 저장하기 전에 뛴 기록은 비어 있습니다.
  // 토막 여럿인 이유: 신호가 오래 끊긴 구간을 선으로 잇지 않기 위해서입니다.
  final List<List<LatLng>> segments;

  const RunLog({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.goldEarned,
    required this.expEarned,
    required this.createdAt,
    required this.segments,
  });

  // 지도를 그릴 만큼 점이 있는 토막이 하나라도 있는지
  bool get hasPath => segments.any((segment) => segment.length >= 2);

  List<LatLng> get path => [for (final segment in segments) ...segment];

  factory RunLog.fromMap(Map<String, dynamic> map) {
    return RunLog(
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      goldEarned: (map['goldEarned'] as num?)?.toInt() ?? 0,
      expEarned: (map['expEarned'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      segments: _readSegments(map['path'], map['pathBreaks']),
    );
  }

  // 저장할 값을 만듭니다. (services/user_repository.dart의 saveRun에서 씁니다)
  static Map<String, dynamic> pathFields(List<List<LatLng>> segments) {
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

  // Firestore에는 점을 한 줄로 이어 붙여 저장하고, 토막이 시작되는 자리를 따로 적어둡니다.
  // (Firestore가 배열 안에 배열을 담지 못해서입니다)
  //
  // 경로를 저장하기 전에 만들어진 문서에는 두 필드가 아예 없습니다.
  // 토막을 나누기 전에 저장된 문서에는 path만 있는데, 그건 토막 하나로 봅니다.
  static List<List<LatLng>> _readSegments(Object? rawPath, Object? rawBreaks) {
    if (rawPath is! List) return const [];
    final List<LatLng> points = rawPath
        .whereType<GeoPoint>()
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    if (points.isEmpty) return const [];

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
