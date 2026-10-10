import '../models/run_log.dart';

// ============================================================
// 체감 보정
//
// 완료 창에서 사람이 고른 부하도(feltLevel)와 공식으로 계산한 부하도(loadLevel)를
// 비교합니다. 꾸준히 계산보다 힘들게 느낀다면, 공식이 그 사람의 부담을 낮게 보고
// 있다는 뜻이라 목표를 덜 올립니다. 반대면 조금 더 올립니다. (goal_policy.dart)
//
//   차이 = 최근 28일, 둘 다 있는 러닝의 (고른 값 - 계산값) 평균
//   3번 이상 모였을 때만 씁니다. 한두 번은 그날 컨디션일 수 있습니다.
// ============================================================
class FeltCalibration {
  static const int lookbackDays = 28;
  static const int minRuns = 3;
  static const double threshold = 0.75; // 이보다 크게 벌어지면 보정합니다

  final double? bias; // 양수면 계산보다 힘들게 느낌. 모이지 않았으면 null
  final int runs;

  const FeltCalibration({required this.bias, required this.runs});

  factory FeltCalibration.of(List<RunLog> logs, DateTime now) {
    final DateTime since = now.subtract(const Duration(days: lookbackDays));
    final List<int> diffs = [
      for (final log in logs)
        if (log.feltLevel != null &&
            log.loadLevel != null &&
            (log.createdAt?.isAfter(since) ?? false))
          log.feltLevel! - log.loadLevel!,
    ];
    if (diffs.length < minRuns) {
      return FeltCalibration(bias: null, runs: diffs.length);
    }
    return FeltCalibration(
      bias: diffs.reduce((a, b) => a + b) / diffs.length,
      runs: diffs.length,
    );
  }

  bool get feelsHarder => (bias ?? 0) >= threshold;
  bool get feelsEasier => (bias ?? 0) <= -threshold;
}
