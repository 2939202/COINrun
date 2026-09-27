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
  final List<LatLng> path;

  const RunLog({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.goldEarned,
    required this.expEarned,
    required this.createdAt,
    required this.path,
  });

  // 지도를 그릴 만큼 점이 있는지 (한 점만 있으면 선이 그려지지 않습니다)
  bool get hasPath => path.length >= 2;

  factory RunLog.fromMap(Map<String, dynamic> map) {
    return RunLog(
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      goldEarned: (map['goldEarned'] as num?)?.toInt() ?? 0,
      expEarned: (map['expEarned'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      path: _readPath(map['path']),
    );
  }

  // Firestore에는 GeoPoint 목록으로 저장합니다.
  // 경로를 저장하기 전에 만들어진 문서에는 이 필드가 아예 없습니다.
  static List<LatLng> _readPath(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<GeoPoint>()
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }
}
