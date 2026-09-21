import 'package:latlong2/latlong.dart';

import '../models/run_record.dart';
import '../services/location_service.dart';

// 러닝 세션의 진행 상태
enum RunState { idle, running, paused }

// ============================================================
// 러닝 한 번의 기록을 모으는 곳 (화면과 분리되어 있어서 테스트할 수 있습니다)
//
//   - 거리: GPS 위치가 들어올 때마다 이전 위치와의 거리를 더함
//   - 움직인 시간: 두 위치 사이 속도가 걷는 속도 이상일 때만 그 시간을 더함
//                  (시작만 눌러 두고 가만히 서 있으면 경험치가 쌓이지 않음)
//   - 걸음 수: 폰 걸음 센서 값으로 계산. 센서가 없으면(웹, 일부 기기) 거리로 추정
// ============================================================
class RunTracker {
  // 이 속도(m/s) 이상이면 움직이는 중으로 봅니다. 1.0m/s = 시속 3.6km (느린 걸음)
  static const double minMovingSpeed = 1.0;

  // 위치 사이 간격이 이보다 길면(신호 끊김 등) 그 시간은 움직인 시간에 넣지 않습니다.
  static const Duration maxGap = Duration(seconds: 10);

  // 걸음 센서가 없을 때 쓰는 평균 보폭 (m)
  static const double estimatedStrideMeters = 0.75;

  RunState _state = RunState.idle;
  final Stopwatch _stopwatch = Stopwatch();

  double _distance = 0;
  Duration _movingTime = Duration.zero;
  List<LatLng> _path = [];
  LatLng? _lastPoint;
  DateTime? _lastTime;

  // 걸음 센서는 "폰을 켠 뒤 누적 걸음 수"를 주기 때문에, 구간 시작 값을 빼서 계산합니다.
  bool _hasStepSensor = false;
  int? _latestSensorSteps;
  int? _segmentStartSteps; // 시작/재개한 순간의 센서 값
  int _stepsBeforeSegment = 0; // 일시정지 전까지 모은 걸음 수

  RunState get state => _state;
  List<LatLng> get path => _path;

  int get steps {
    if (!_hasStepSensor) return (_distance / estimatedStrideMeters).floor();
    return _stepsBeforeSegment + _currentSegmentSteps;
  }

  int get _currentSegmentSteps {
    final int? latest = _latestSensorSteps;
    final int? start = _segmentStartSteps;
    if (_state != RunState.running || latest == null || start == null) return 0;
    return latest - start;
  }

  RunRecord get record => RunRecord(
    elapsed: _stopwatch.elapsed,
    movingTime: _movingTime,
    distanceMeters: _distance,
    steps: steps,
    stepsEstimated: !_hasStepSensor,
  );

  void start(LatLng startPoint, DateTime now) {
    _state = RunState.running;
    _distance = 0;
    _movingTime = Duration.zero;
    _path = [startPoint];
    _lastPoint = startPoint;
    _lastTime = now;
    _stepsBeforeSegment = 0;
    _segmentStartSteps = _latestSensorSteps;
    _stopwatch
      ..reset()
      ..start();
  }

  void pause() {
    _stepsBeforeSegment += _currentSegmentSteps;
    _segmentStartSteps = null;
    _state = RunState.paused;
    _stopwatch.stop();
  }

  void resume(DateTime now) {
    _state = RunState.running;
    _segmentStartSteps = _latestSensorSteps;
    // 일시정지 중에 이동한 거리/시간은 세지 않도록 기준점을 지금으로 옮깁니다.
    _lastTime = now;
    _stopwatch.start();
  }

  // 완료 후 다음 러닝을 위해 비웁니다.
  void reset() {
    _state = RunState.idle;
    _stopwatch
      ..stop()
      ..reset();
    _distance = 0;
    _movingTime = Duration.zero;
    _path = [];
    _stepsBeforeSegment = 0;
    _segmentStartSteps = null;
  }

  void addPosition(LatLng point, DateTime time) {
    final LatLng? previous = _lastPoint;
    final DateTime? previousTime = _lastTime;
    _lastPoint = point;
    _lastTime = time;

    if (_state != RunState.running || previous == null) return;

    final double meters = LocationService.distanceBetween(
      previous.latitude,
      previous.longitude,
      point.latitude,
      point.longitude,
    );
    _distance += meters;
    _path.add(point);

    if (previousTime == null) return;
    final Duration gap = time.difference(previousTime);
    if (gap <= Duration.zero || gap > maxGap) return;

    final double speed = meters / (gap.inMilliseconds / 1000);
    if (speed >= minMovingSpeed) _movingTime += gap;
  }

  void addSensorSteps(int totalSteps) {
    _hasStepSensor = true;
    _latestSensorSteps = totalSteps;
    // 시작했을 때 아직 센서 값이 없었다면, 처음 들어온 값을 기준으로 삼습니다.
    if (_state == RunState.running) _segmentStartSteps ??= totalSteps;
  }
}
