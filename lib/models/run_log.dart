import 'package:cloud_firestore/cloud_firestore.dart';

// Firestore의 users/{userId}/runs/{runId} 문서 - 저장된 러닝 기록 한 개
class RunLog {
  final double distanceMeters;
  final int durationSeconds;
  final int goldEarned;
  final int expEarned;
  final DateTime? createdAt; // 저장 직후 잠깐은 서버 시간이 아직 없어서 null일 수 있음

  const RunLog({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.goldEarned,
    required this.expEarned,
    required this.createdAt,
  });

  factory RunLog.fromMap(Map<String, dynamic> map) {
    return RunLog(
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      goldEarned: (map['goldEarned'] as num?)?.toInt() ?? 0,
      expEarned: (map['expEarned'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
