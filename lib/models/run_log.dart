import 'package:cloud_firestore/cloud_firestore.dart';

import 'run_route.dart';

// Firestore의 users/{userId}/runs/{runId} 문서 - 저장된 러닝 기록 한 개
//
// 경로는 여기 들어 있지 않습니다. 무겁기도 하고 목록에서는 쓰지도 않아서
// users/{userId}/routes/{runId}에 따로 둡니다. (models/run_route.dart 참고)
class RunLog {
  final String id; // routes/{id}로 경로를 찾을 때 씁니다.
  final double distanceMeters;
  final int durationSeconds;
  final int goldEarned;
  final int expEarned;
  final DateTime? createdAt; // 저장 직후 잠깐은 서버 시간이 아직 없어서 null일 수 있음

  // 경로를 따로 두기 전에 저장된 기록은 이 문서 안에 경로를 들고 있습니다.
  // 그런 기록도 지도가 보이도록 읽어둡니다. 새 기록에서는 항상 비어 있습니다.
  final RunRoute legacyRoute;

  const RunLog({
    required this.id,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.goldEarned,
    required this.expEarned,
    required this.createdAt,
    required this.legacyRoute,
  });

  factory RunLog.fromMap(String id, Map<String, dynamic> map) {
    return RunLog(
      id: id,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      goldEarned: (map['goldEarned'] as num?)?.toInt() ?? 0,
      expEarned: (map['expEarned'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      legacyRoute: RunRoute.fromMap(map),
    );
  }
}
