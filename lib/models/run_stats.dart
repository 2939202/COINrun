import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// 한 주 또는 한 달의 러닝 요약 (users/{userId}/stats/{key} 문서 한 개)
//
// 러닝을 저장할 때마다 이번 주 칸과 이번 달 칸에 숫자를 더합니다.
// 기록을 지우면 같은 만큼 빼서, 지운 러닝이 통계에 남지 않게 합니다.
//
// 상세 기록은 60개까지만 보관하지만 이 요약은 지우지 않습니다.
// 그래서 오래된 러닝의 지도는 사라져도 "그 달에 얼마나 뛰었나"는 영원히 남습니다.
// 칸 이름을 정하는 규칙은 game/stats_period.dart를 보세요.
// ============================================================
class RunStats {
  final String key; // w2026-09-28 또는 m2026-09
  final DateTime? startAt; // 그 주의 월요일, 또는 그 달의 1일
  final bool isWeek;

  final int runs; // 뛴 횟수
  final double distanceMeters;
  final int seconds; // 러닝 시간 합
  final int movingSeconds; // 실제로 움직인 시간 합
  final int steps;
  final int gold;
  final int exp;

  const RunStats({
    required this.key,
    required this.startAt,
    required this.isWeek,
    required this.runs,
    required this.distanceMeters,
    required this.seconds,
    required this.movingSeconds,
    required this.steps,
    required this.gold,
    required this.exp,
  });

  double get distanceKm => distanceMeters / 1000;

  // 한 번 뛸 때 평균 몇 km인지. 뛴 적이 없으면 0.
  double get averageKm => runs == 0 ? 0 : distanceKm / runs;

  factory RunStats.fromMap(String key, Map<String, dynamic> map) {
    return RunStats(
      key: key,
      startAt: (map['startAt'] as Timestamp?)?.toDate(),
      isWeek: map['isWeek'] as bool? ?? key.startsWith('w'),
      runs: (map['runs'] as num?)?.toInt() ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      seconds: (map['seconds'] as num?)?.toInt() ?? 0,
      movingSeconds: (map['movingSeconds'] as num?)?.toInt() ?? 0,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      gold: (map['gold'] as num?)?.toInt() ?? 0,
      exp: (map['exp'] as num?)?.toInt() ?? 0,
    );
  }

  // 요약 칸에 더하거나 뺄 값을 만듭니다.
  //
  // FieldValue.increment를 쓰는 이유: 읽어서 더하고 다시 쓰는 방식이면 두 곳에서
  // 동시에 저장할 때 한쪽이 덮어써집니다. increment는 서버가 알아서 더해줘서
  // 먼저 읽을 필요도 없고 덮어쓸 일도 없습니다.
  //
  // sign에 -1을 넣으면 같은 값을 빼줍니다. (기록을 지울 때)
  static Map<String, dynamic> changes({
    required DateTime startAt,
    required bool isWeek,
    required double distanceMeters,
    required int seconds,
    required int movingSeconds,
    required int steps,
    required int gold,
    required int exp,
    int sign = 1,
  }) {
    return {
      // 칸을 처음 만들 때 필요한 값. 이미 있으면 같은 값으로 다시 써도 탈이 없습니다.
      'startAt': Timestamp.fromDate(startAt),
      'isWeek': isWeek,

      'runs': FieldValue.increment(sign),
      'distanceMeters': FieldValue.increment(distanceMeters * sign),
      'seconds': FieldValue.increment(seconds * sign),
      'movingSeconds': FieldValue.increment(movingSeconds * sign),
      'steps': FieldValue.increment(steps * sign),
      'gold': FieldValue.increment(gold * sign),
      'exp': FieldValue.increment(exp * sign),
    };
  }
}
