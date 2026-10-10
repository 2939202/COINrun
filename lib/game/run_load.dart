import '../models/run_record.dart';
import 'training_model.dart';

// ============================================================
// 러닝 한 번의 부하도 (1~5)
//
// 이번 러닝이 몸에 준 부담입니다. 완료 창의 1~5 띠로 보여주고, 기록에 같이 저장합니다.
// 계산은 training_model.dart와 같습니다.
//
//   강도 = 내 역치 페이스 / 이번 페이스      (역치로 달리면 1.0)
//   부하 = 움직인 시간(시) x 강도^2 x 100    (역치로 1시간 = 100)
//
// 역치 페이스는 최근 기록으로 추정합니다. 그래서 같은 5km라도 평소보다 빠르게 뛰면
// 부하가 크고, 평소 페이스로 가볍게 뛰면 작게 나옵니다. 사람마다 기준이 다릅니다.
//
// [단계] 역치로 1시간(100)을 4단계 위쪽 끝 근처로 둡니다.
//   1 가벼움   ~ 25    (20분 가벼운 조깅, 산책)
//   2 보통     25~50
//   3 적당함   50~80
//   4 높음     80~120
//   5 매우 높음 120~   (역치 가까이로 1시간 넘게)
// ============================================================
class RunLoad {
  static const List<double> levelStarts = [0, 25, 50, 80, 120];
  static const List<String> labels = ['가벼움', '보통', '적당함', '높음', '매우 높음'];

  final double load;
  final double intensity;
  final double thresholdPace; // 분/km
  final int thresholdFromRuns; // 역치 추정에 쓴 지난 러닝 수 (0이면 기본값)
  final int movingMinutes;
  final bool walk;

  const RunLoad({
    required this.load,
    required this.intensity,
    required this.thresholdPace,
    required this.thresholdFromRuns,
    required this.movingMinutes,
    required this.walk,
  });

  // history: 이번 러닝을 뺀 지난 기록 (역치 페이스를 추정하는 데 씁니다)
  factory RunLoad.of(
    RunRecord run,
    List<Session> history, {
    required DateTime now,
  }) {
    final TrainingState state = TrainingModel.analyze(history, now);
    final Session session = Session(
      day: DateTime(now.year, now.month, now.day),
      km: run.distanceKm,
      movingSeconds: run.movingTime.inSeconds,
      steps: run.steps,
      stepsEstimated: run.stepsEstimated,
    );
    if (!session.usable) {
      return RunLoad(
        load: 0,
        intensity: 0,
        thresholdPace: state.thresholdPace,
        thresholdFromRuns: state.thresholdFromRuns,
        movingMinutes: (run.movingTime.inSeconds / 60).round(),
        walk: false,
      );
    }
    return RunLoad(
      load: TrainingModel.loadOf(session, state.thresholdPace),
      intensity: TrainingModel.intensityOf(session, state.thresholdPace),
      thresholdPace: state.thresholdPace,
      thresholdFromRuns: state.thresholdFromRuns,
      movingMinutes: (session.movingSeconds / 60).round(),
      walk: session.isWalk,
    );
  }

  int get level {
    for (int i = levelStarts.length - 1; i >= 0; i--) {
      if (load >= levelStarts[i]) return i + 1;
    }
    return 1;
  }

  String get label => labels[level - 1];

  Map<String, dynamic> toMap() => {
    'load': double.parse(load.toStringAsFixed(1)),
    'loadLevel': level,
    'intensity': double.parse(intensity.toStringAsFixed(3)),
    'thresholdPace': double.parse(thresholdPace.toStringAsFixed(2)),
  };
}
