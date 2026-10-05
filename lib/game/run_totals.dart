import '../models/run_log.dart';
import '../models/user_model.dart';

// ============================================================
// 홈의 누적 기록(총 킬로미터, 총 시간, 걸음)에서 기록 하나를 빼거나 다시 더합니다.
//
// 러닝 기록을 삭제하면 빼고(sign -1), 휴지통에서 되살리면 더합니다(sign 1).
// 거리 랭킹과 홈의 순위도 이 거리 값으로 매겨지므로 같이 내려갑니다.
//
// 0 아래로는 내려가지 않습니다. 누적 기록을 붙이기 전에 저장된 옛 기록을 지우면
// 원래 더해진 적이 없는 값을 빼게 되기 때문입니다.
// ============================================================
class RunTotals {
  final double distanceMeters;
  final int runSeconds;
  final int movingSeconds;
  final int steps;

  const RunTotals({
    required this.distanceMeters,
    required this.runSeconds,
    required this.movingSeconds,
    required this.steps,
  });

  factory RunTotals.apply(UserModel user, RunLog run, int sign) {
    return RunTotals(
      distanceMeters: _clamp(user.totalDistance + sign * run.distanceMeters),
      runSeconds: _clamp(
        user.totalRunSeconds + sign * run.durationSeconds,
      ).toInt(),
      movingSeconds: _clamp(
        user.totalMovingSeconds + sign * run.movingSeconds,
      ).toInt(),
      steps: _clamp(user.totalSteps + sign * run.steps).toInt(),
    );
  }

  static double _clamp(num value) => value < 0 ? 0 : value.toDouble();

  // users 문서에 그대로 merge할 값
  Map<String, dynamic> toMap() => {
    'totalDistance': distanceMeters,
    'totalRunSeconds': runSeconds,
    'totalMovingSeconds': movingSeconds,
    'totalSteps': steps,
  };
}
