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

  // 이보다 적게 움직인 위치는 무시합니다.
  //
  // GPS는 가만히 있어도 몇 미터씩 흔들립니다. 2초마다 위치를 받으니 그대로 더하면
  // 서 있기만 해도 거리가 계속 늘어납니다.
  //
  // 무시할 때 기준점을 옮기지 않는 것이 중요합니다. 기준점을 옮겨버리면 천천히 걷는 사람은
  // 매번 3m 미만이라 영영 거리가 쌓이지 않습니다. 그대로 두면 3m를 넘는 순간 잡힙니다.
  static const double minMoveMeters = 3;

  // 위치 사이 간격이 이보다 길면(신호 끊김 등) 그 시간은 움직인 시간에 넣지 않습니다.
  static const Duration maxGap = Duration(seconds: 10);

  // 한 번에 이보다 멀리 뛴 위치는 거리에 더하지 않습니다.
  //
  // 지하도나 건물 사이에서 신호가 잠깐 끊겼다 돌아오면, 그동안 지나온 길을 건너뛰고
  // 뚝 떨어진 점 하나가 들어옵니다. 그대로 더하면 "직선으로 갔다"고 치게 되는데
  // 실제로 지나온 길이 아닙니다. 한 바퀴 돌아 제자리로 왔으면 0m가 되고,
  // 곧장 갔으면 한꺼번에 더해져서 어느 쪽이든 틀립니다.
  //
  // 200m는 달리는 속도로 40초쯤입니다. 그보다 짧게 끊긴 건 직선으로 봐도 큰 차이가 없어서
  // 그대로 더합니다. 그보다 길게 끊겼으면 믿지 않고 경로를 끊습니다.
  static const double maxJumpMeters = 200;

  // 이보다 빠르게 움직인 구간은 달린 것으로 치지 않습니다. 7m/s = 시속 25.2km
  //
  // 사람이 몇 분 이상 낼 수 있는 속도를 넉넉히 넘는 값입니다. (마라톤 세계 기록이 약 5.7m/s)
  // 차나 빠른 자전거로 이동하면서 거리·경험치·코스 코인을 모으는 것을 막습니다.
  // 걸음 센서가 없는 폰은 걸음을 거리로 추정하므로, 여기서 뺀 거리는 골드에도 들어가지 않습니다.
  //
  // GPS가 순간적으로 튀어 생기는 가짜 고속 구간도 같이 걸러집니다.
  static const double maxRunningSpeed = 7.0;

  // 걸음 센서가 없을 때 쓰는 평균 보폭 (m)
  static const double estimatedStrideMeters = 0.75;

  RunState _state = RunState.idle;
  final Stopwatch _stopwatch = Stopwatch();

  double _distance = 0;
  Duration _movingTime = Duration.zero;
  // 경로는 토막 여럿으로 들고 있습니다. 신호가 오래 끊기거나 일시정지했다 다시 시작하면
  // 그 사이는 어디로 갔는지 모르므로, 이어 그리지 않고 새 토막을 시작합니다.
  List<List<LatLng>> _segments = [];
  LatLng? _lastPoint;
  DateTime? _lastTime;

  // 걸음 센서는 "폰을 켠 뒤 누적 걸음 수"를 주기 때문에, 구간 시작 값을 빼서 계산합니다.
  // 너무 멀어서 버린 점프 횟수. 화면 아래 진단 줄에 보여줍니다.
  int _rejectedJumps = 0;

  // 너무 빨라서 뺀 구간 수와 거리. 화면 안내와 진단 줄에 씁니다.
  int _tooFastCount = 0;
  double _tooFastMeters = 0;
  bool _lastWasTooFast = false;

  // 개발자 모드 조이스틱은 한 번에 5m씩 순간이동해서 속도 제한에 늘 걸립니다.
  // 시연이 되도록 조이스틱을 쓰는 동안만 끕니다.
  bool enforceSpeedLimit = true;

  bool _hasStepSensor = false;
  int? _latestSensorSteps;
  int? _segmentStartSteps; // 시작/재개한 순간의 센서 값
  int _stepsBeforeSegment = 0; // 일시정지 전까지 모은 걸음 수

  RunState get state => _state;
  int get rejectedJumps => _rejectedJumps;
  int get tooFastCount => _tooFastCount;
  double get tooFastMeters => _tooFastMeters;

  // 방금 들어온 위치가 너무 빨라서 빠졌는지. 이때는 코스 코인도 먹지 않습니다.
  bool get lastWasTooFast => _lastWasTooFast;

  // 지도에 그릴 때 씁니다. 토막마다 선을 따로 그으면 끊긴 구간이 이어지지 않습니다.
  List<List<LatLng>> get segments => _segments;

  // 저장하거나 지도 범위를 잡을 때처럼 점만 필요할 때 씁니다.
  List<LatLng> get path => [for (final segment in _segments) ...segment];

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
    segments: [
      for (final segment in _segments) List<LatLng>.unmodifiable(segment),
    ],
  );

  // startPoint가 null이면 아직 GPS를 못 잡은 것입니다. 그 상태로도 시작할 수 있고,
  // 첫 위치가 들어오는 자리를 출발점으로 삼습니다.
  //
  // 예전에는 GPS가 없으면 기본 좌표(서울 시청)를 출발점으로 넣었습니다. 그러면 첫 위치가
  // 들어오는 순간 서울 시청에서 거기까지가 한 번에 뛴 것으로 계산돼서, 멀다는 이유로
  // 통째로 버려지고 경로가 시작되지 않았습니다.
  void start(LatLng? startPoint, DateTime now) {
    _state = RunState.running;
    _distance = 0;
    _movingTime = Duration.zero;
    _segments = startPoint == null
        ? []
        : [
            [startPoint],
          ];
    _rejectedJumps = 0;
    _tooFastCount = 0;
    _tooFastMeters = 0;
    _lastWasTooFast = false;
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
    // 멈춰 있는 동안 자리를 옮겼을 수 있습니다. 그 사이를 선으로 잇지 않도록 새 토막을 시작합니다.
    final LatLng? here = _lastPoint;
    if (here != null) _segments.add([here]);
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
    _segments = [];
    _stepsBeforeSegment = 0;
    _segmentStartSteps = null;
  }

  void addPosition(LatLng point, DateTime time) {
    final LatLng? previous = _lastPoint;
    final DateTime? previousTime = _lastTime;

    // 달리는 중이 아니면 기준점만 따라 옮깁니다.
    // (일시정지 중에 이동한 것이 재개할 때 한꺼번에 더해지지 않도록)
    if (_state != RunState.running) {
      _lastPoint = point;
      _lastTime = time;
      return;
    }

    // GPS를 못 잡은 채로 시작했으면, 첫 위치가 들어오는 여기가 출발점입니다.
    if (previous == null) {
      _lastPoint = point;
      _lastTime = time;
      _segments.add([point]);
      return;
    }

    final double meters = LocationService.distanceBetween(
      previous.latitude,
      previous.longitude,
      point.latitude,
      point.longitude,
    );

    // 제자리 흔들림은 버립니다. 기준점은 그대로 둡니다. (minMoveMeters 설명 참고)
    if (meters < minMoveMeters) return;

    _lastPoint = point;
    _lastTime = time;
    _lastWasTooFast = false;

    // 너무 멀리 건너뛴 점은 지나온 길로 치지 않습니다. (maxJumpMeters 설명 참고)
    if (meters > maxJumpMeters) {
      _rejectedJumps += 1;
      _segments.add([point]);
      return;
    }

    final Duration gap = previousTime == null
        ? Duration.zero
        : time.difference(previousTime);
    final double? speed = gap > Duration.zero
        ? meters / (gap.inMilliseconds / 1000)
        : null;

    // 달리는 속도가 아니면 거리·시간에 넣지 않고, 지도에도 잇지 않습니다.
    // (차로 지나간 길이 달린 길처럼 그려지면 안 됩니다)
    if (enforceSpeedLimit && speed != null && speed > maxRunningSpeed) {
      _tooFastCount += 1;
      _tooFastMeters += meters;
      _lastWasTooFast = true;
      _segments.add([point]);
      return;
    }

    _distance += meters;
    if (_segments.isEmpty) _segments.add([]);
    _segments.last.add(point);

    if (speed == null || gap > maxGap) return;
    if (speed >= minMovingSpeed) _movingTime += gap;
  }

  // 걸음 센서를 쓰지 않는 상태로 되돌립니다. 다시 거리로 걸음 수를 추정합니다.
  //
  // 개발용 시뮬레이터를 켤 때 부릅니다. 시뮬레이터는 위치만 가짜로 움직이고
  // 진짜 걸음은 생기지 않기 때문에, 센서를 켜둔 채로 두면 걸음 수가 0에서 멈추고
  // 골드도 쌓이지 않습니다.
  void disableStepSensor() {
    _hasStepSensor = false;
    _latestSensorSteps = null;
    _segmentStartSteps = null;
    _stepsBeforeSegment = 0;
  }

  void addSensorSteps(int totalSteps) {
    _hasStepSensor = true;
    _latestSensorSteps = totalSteps;
    // 시작했을 때 아직 센서 값이 없었다면, 처음 들어온 값을 기준으로 삼습니다.
    if (_state == RunState.running) _segmentStartSteps ??= totalSteps;
  }
}
