import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:vibration/vibration.dart';

import '../game/course_coins.dart';
import '../game/equipment_rules.dart';
import '../game/run_load.dart';
import '../game/run_rules.dart';
import '../game/run_tracker.dart';
import '../game/training_model.dart';
import '../models/course.dart';
import '../models/equipment_set.dart';
import '../models/run_record.dart';
import '../models/user_model.dart';
import '../services/app_permissions.dart';
import '../services/course_repository.dart';
import '../services/location_service.dart';
import '../services/seoul_districts.dart';
import '../services/step_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/course_widgets.dart' show slideFromRight;
import '../widgets/home_widgets.dart' show DoubleRule, TotalBlock;
import '../widgets/gold_coin.dart';
import '../widgets/map_tiles.dart';
import '../widgets/run_app_bar.dart';
import 'course_screen.dart';
import 'run_report.dart';

// ============================================================
// RunScreen: 지도 + 러닝 기록 화면
//
// 흐름: 시작 전(idle) -> 달리는 중(running) <-> 일시정지(paused) -> 완료
//   - 완료를 누르면 UserRepository가 보상을 계산해 Firestore에 저장하고,
//     완료 리포트를 보여줍니다.
//   - 코스 러닝은 걸음 대신 코스 위 코인으로 골드를 줍니다. (game/course_coins.dart)
//   - "코스 만들기"로 열면 자유 러닝과 똑같이 달리고, 완료하면 그 길을 사설 코스로
//     올릴지 묻습니다. 기록과 보상은 평소대로 저장됩니다.
//   - 이 화면은 두 얼굴을 가집니다. 코스 없이 열면 "러닝", 코스를 들고 열면
//     "코스 러닝"입니다. 앱바의 ⇄로 러닝 <-> 코스 러닝(코스 고르기)을 오가고,
//     ←는 언제나 홈으로 나갑니다. 오가는 화면은 쌓지 않고 바꿔 끼웁니다.
//
// [알림]
//   알림창의 "달리는 중" 알림은 시작을 누른 뒤부터 완료할 때까지만 뜹니다.
//   시작 전에는 포그라운드 서비스 없이 위치만 받아 지도에 내 자리를 찍습니다.
//
// [숨은 개발자 모드]
//   지도 오른쪽 아래 나침반을 빠르게 6번 두드리면 켜집니다. 다시 6번이면 꺼집니다.
//   켜지면 나침반 둘레에 방향 버튼(시뮬레이터)이 생기고 지도 위에 GPS 진단 줄이
//   보입니다. 시연할 때 밖에 나가지 않고도 달리는 모습을 보여주려고 만든 것이라
//   출시 빌드에서도 열립니다.
// ============================================================

enum MoveDirection { up, down, left, right }

class RunScreen extends StatefulWidget {
  final String userId;

  // 코스 러닝이면 그 코스. null이면 자유 러닝
  final Course? course;

  // 사설 코스 만들기. 자유 러닝처럼 달리고, 끝나면 그 길을 코스로 올립니다.
  final bool creatingCourse;

  const RunScreen({
    super.key,
    required this.userId,
    this.course,
    this.creatingCourse = false,
  });

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  static const LatLng _defaultPosition = LatLng(37.5665, 126.9780); // 서울 시청
  static const double _initialZoom = 17;

  // 위치
  final MapController _mapController = MapController();

  // 지도가 화면에 올라온 뒤에야 현재 배율을 읽을 수 있습니다.
  // (올라오기 전에 _mapController.camera를 읽으면 오류가 납니다)
  bool _isMapReady = false;
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _currentPosition; // 아직 GPS를 못 받았으면 null

  // 러닝 세션 (거리/움직인 시간/걸음 수 계산은 RunTracker가 담당)
  final RunTracker _tracker = RunTracker();
  StreamSubscription<int>? _stepSubscription;
  Timer? _uiTimer; // 1초마다 화면을 다시 그리기만 하는 타이머
  bool _isSaving = false;

  // 진단용 - 왜 경로가 안 그려지는지 화면에서 바로 보려고 셉니다. (개발 빌드에만 보임)
  int _fixCount = 0; // 위치를 받은 횟수
  DateTime? _lastFixAt; // 마지막으로 받은 시각
  double? _lastAccuracy; // 마지막 위치의 오차(m)
  int _droppedByAccuracy = 0; // 오차가 커서 버린 횟수
  String? _streamError; // 스트림에서 난 오류 (화면에 그대로 띄웁니다)
  bool _usingForegroundService = false; // 포그라운드 서비스로 받고 있는지
  Timer? _watchdog; // 위치가 아예 안 들어올 때 되돌리기 위한 감시

  // 고른 코스. 없으면 자유 러닝입니다.
  Course? get _course => widget.course;

  // 코스 위 코인. 시작 전에도 지도에 보이고, 시작할 때 새로 깝니다.
  late CourseCoins? _coins = _freshCoins();

  CourseCoins? _freshCoins() {
    final Course? course = _course;
    return course == null ? null : CourseCoins.forCourse(course);
  }

  // 출발점에서 이보다 멀리서 시작하면 알려줍니다. 코인을 하나도 못 먹으니까요.
  static const double _farFromCourseMeters = 300;

  // 숨은 개발자 모드 (나침반 6번)
  bool _devMode = false;
  int _compassTaps = 0;
  DateTime? _lastCompassTap;
  static const int _devModeTaps = 6;
  static const Duration _tapGap = Duration(milliseconds: 700);

  // 개발용 시뮬레이터
  bool _useSimulator = false;
  Timer? _simulatorTimer;
  static const double _simulatorStepMeters = 5;

  LatLng get _position => _currentPosition ?? _defaultPosition;

  @override
  void initState() {
    super.initState();
    // 들어올 때는 알림 없이 위치만 받습니다. 시작을 누르면 알림을 붙여 다시 엽니다.
    //
    // geolocator는 이미 열린 스트림이 있으면 새 설정을 무시하고 그걸 돌려줍니다
    // (geolocator_android.dart:167). 그래서 다시 열 때는 _startGps가 먼저 기존
    // 구독을 끊어 스트림을 닫은 뒤 새 설정으로 엽니다.
    _prepare();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stepSubscription?.cancel();
    _uiTimer?.cancel();
    _simulatorTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 위치 수신
  // ----------------------------------------------------------
  // 권한부터 확보하고 GPS와 걸음 센서를 켭니다.
  //
  // 순서를 지키는 것이 중요합니다. 예전에는 GPS와 걸음 센서를 동시에 켜면서 각자
  // 권한을 요청했는데, 안드로이드는 권한 창을 하나만 띄울 수 있어서 뒤엣것이 씹혔습니다.
  // 허용을 눌러도 안 먹거나 엉뚱한 때 다시 뜨던 것이 이것 때문이었습니다.
  //
  // 보통은 로그인 직후 권한 화면에서 이미 받아둔 상태라 여기서는 그냥 통과합니다.
  // "나중에 하기"를 고른 경우를 위해 여기서도 한 번 확인합니다.
  Future<void> _prepare() async {
    final status = await AppPermissions.check();
    if (!status.canRecord) await AppPermissions.request();
    if (!mounted) return;

    // 스트림이 첫 위치를 줄 때까지 기다리지 않도록, 폰이 이미 알고 있는 위치를
    // 먼저 지도에 찍어둡니다.
    await _showLastKnownPosition();
    if (!mounted) return;

    await _startGps(withForegroundService: false);
    if (!mounted) return;

    await _startStepSensor();
  }

  // 폰이 마지막으로 알던 위치를 지도에 찍어둡니다. 기다리지 않고 바로 끝납니다.
  Future<void> _showLastKnownPosition() async {
    final position = await LocationService.lastKnownPosition();
    if (!mounted || position == null) return;
    if (_currentPosition != null || _useSimulator) return; // 이미 새 위치가 들어왔으면 그대로

    setState(
      () => _currentPosition = LatLng(position.latitude, position.longitude),
    );
    _moveMap(_position);
  }

  // 위치 스트림을 엽니다. 이 화면에 들어올 때 한 번만 부릅니다.
  //
  // withForegroundService를 켜면 알림창에 알림이 하나 뜨고, 그게 떠 있는 동안
  // 화면을 꺼도 위치가 계속 들어옵니다. 이게 없으면 안드로이드가 전달을 끊습니다.
  //
  // withForegroundService를 안 주면 지금 러닝 중인지로 정합니다.
  Future<void> _startGps({bool? withForegroundService}) async {
    final bool foreground =
        withForegroundService ?? _tracker.state != RunState.idle;
    final String? error = await LocationService.ensurePermission();
    if (error != null) {
      if (mounted) setState(() => _streamError = error);
      _showMessage(error);
      return;
    }
    if (!mounted || _useSimulator) return;

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    setState(() {
      _usingForegroundService = foreground;
      _streamError = null;
    });

    _positionSubscription =
        LocationService.positionStream(
          keepAliveInBackground: foreground,
        ).listen(
          (position) {
            if (!mounted) return;
            setState(() {
              _fixCount += 1;
              _lastFixAt = DateTime.now();
              _lastAccuracy = position.accuracy;
            });

            // 오차가 큰 위치는 버립니다 (GPS 흔들림 때문에 거리가 쌓이는 것 방지)
            if (position.accuracy > LocationService.maxAccuracyMeters) {
              setState(() => _droppedByAccuracy += 1);
              return;
            }
            _onNewPosition(LatLng(position.latitude, position.longitude));
          },
          onError: (Object error) {
            // 오류를 화면에 그대로 띄웁니다. 예전에는 로그로만 남겨서 폰에서는 알 수 없었습니다.
            debugPrint('GPS 오류: $error');
            if (mounted) setState(() => _streamError = '$error');
          },
        );

    _startWatchdog(foreground);
  }

  // 포그라운드 서비스를 붙였는데 위치가 하나도 안 들어오면, 서비스가 시작에 실패한 것입니다.
  // 그때는 서비스 없이 다시 엽니다. 백그라운드는 포기하더라도 화면을 켜둔 동안은 기록돼야 합니다.
  void _startWatchdog(bool withForegroundService) {
    _watchdog?.cancel();
    if (!withForegroundService) return;

    _watchdog = Timer(const Duration(seconds: 20), () {
      if (!mounted || _fixCount > 0 || _useSimulator) return;
      _showMessage('위치가 들어오지 않아 백그라운드 기록을 끄고 다시 시도합니다.');
      _startGps(withForegroundService: false);
    });
  }

  // GPS든 시뮬레이터든 새 위치는 모두 여기로 들어옵니다.
  void _onNewPosition(LatLng newPosition) {
    setState(() {
      _currentPosition = newPosition;
      _tracker.addPosition(newPosition, DateTime.now());
    });
    _moveMap(newPosition);
    if (_tracker.lastWasTooFast) {
      _warnTooFast();
      return; // 차로 지나가면서 코인을 먹지 못하게 합니다.
    }
    _checkCoins(newPosition);
  }

  // 너무 빠르다는 안내는 30초에 한 번만 띄웁니다. 차를 타면 2초마다 걸리기 때문입니다.
  DateTime? _lastTooFastWarning;

  void _warnTooFast() {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastTooFastWarning;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastTooFastWarning = now;
    _showMessage(
      '이동 속도가 너무 빨라요. 시속 '
      '${(RunTracker.maxRunningSpeed * 3.6).round()}km를 넘는 구간은 기록되지 않아요.',
    );
  }

  // 달리는 중에만 코인을 먹습니다. 일시정지 중에 걸어가서 먹으면 안 됩니다.
  void _checkCoins(LatLng position) {
    final CourseCoins? coins = _coins;
    if (coins == null || _tracker.state != RunState.running) return;

    final bool wasAll = coins.allCollected;
    final CoinUpdate update = coins.update(position);
    if (update.isEmpty) return;
    setState(() {}); // 먹은 코인을 지도에서 지웁니다.

    if (update.collected > 0) {
      _buzz(const [0, 90]);
    } else if (update.passed > 0) {
      // 왕복 코스의 가는 길: 아직 못 먹는다는 뜻으로 짧게 두 번
      _buzz(const [0, 35, 70, 35]);
    }
    if (update.turned) {
      _buzz(const [0, 250]);
      _showMessage('반환점! 이제 돌아오면서 코인을 먹어요.');
    }
    if (!wasAll && coins.allCollected) {
      _buzz(const [0, 120, 80, 120, 80, 260]);
      _showMessage('코인을 다 먹었어요! 골드 ${coins.completionBonus}배');
    }
  }

  // 진동이 없는 기종에서는 조용히 넘어갑니다.
  Future<void> _buzz(List<int> pattern) async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: pattern);
      }
    } catch (error) {
      debugPrint('진동 실패: $error');
    }
  }

  // 내 위치를 화면 가운데에 둡니다. 배율은 지금 화면에 맞춰진 값을 그대로 씁니다.
  // (예전에는 _initialZoom을 넘겨서, 손으로 확대해도 다음 위치가 들어오는 순간
  //  원래 배율로 되돌아갔습니다)
  //
  // 지도 조작이 실패해도 기록은 계속돼야 합니다. 화면을 끈 동안에는 지도가 그려지지
  // 않는데, 그때 오류가 나서 거리와 경로까지 멈추면 안 됩니다.
  //
  // 코스 러닝은 시작 전까지 코스 전체를 보여줘야 해서 따라가지 않습니다.
  void _moveMap(LatLng position) {
    if (_course != null && _tracker.state == RunState.idle) return;
    try {
      _mapController.move(position, _currentZoom);
    } catch (error) {
      debugPrint('지도 이동 실패 (기록은 계속됩니다): $error');
    }
  }

  double get _currentZoom =>
      _isMapReady ? _mapController.camera.zoom : _initialZoom;

  // ----------------------------------------------------------
  // 걸음 센서
  // ----------------------------------------------------------
  Future<void> _startStepSensor() async {
    // 권한은 _prepare에서 이미 순서대로 받았습니다. 여기서는 확인만 합니다.
    final bool granted = await StepService.hasPermission();
    if (!mounted) return;
    if (!granted) {
      // 센서를 못 쓰면 RunTracker가 거리로 걸음 수를 추정합니다.
      if (StepService.isSupported) {
        _showMessage('걸음 수 권한이 없어서 거리로 걸음 수를 추정해요.');
      }
      return;
    }
    _stepSubscription = StepService.stepCountStream().listen(
      (steps) => setState(() => _tracker.addSensorSteps(steps)),
      onError: (Object error) => debugPrint('걸음 센서 오류: $error'),
    );
  }

  // ----------------------------------------------------------
  // 러닝 세션 (시작 / 일시정지 / 재개 / 완료)
  // ----------------------------------------------------------
  void _start() {
    setState(() {
      _fixCount = 0;
      _droppedByAccuracy = 0;
      _lastFixAt = null;
      // 아직 GPS를 못 잡았으면 null을 넘깁니다. 기본 좌표(서울 시청)를 출발점으로 쓰면
      // 첫 위치가 들어올 때 거기까지가 한 번에 뛴 것으로 계산돼 통째로 버려집니다.
      _tracker.start(_currentPosition, DateTime.now());
      _coins = _freshCoins();
    });
    _startUiTimer();
    _warnIfFarFromCourse();
    _moveMap(_position); // 코스 전체를 보던 지도를 내 자리로
    // 이제부터 화면을 꺼도 기록되도록 알림(포그라운드 서비스)을 붙입니다.
    _startGps(withForegroundService: true);
  }

  void _pause() {
    _uiTimer?.cancel();
    setState(_tracker.pause);
  }

  void _resume() {
    setState(() => _tracker.resume(DateTime.now()));
    _startUiTimer();
  }

  Future<void> _finish() async {
    _uiTimer?.cancel();
    // 저장하는 동안 시간이 흐르지 않도록 먼저 멈추고 최종 기록을 담아둡니다.
    if (_tracker.state == RunState.running) _tracker.pause();
    final RunRecord record = _tracker.record;

    setState(() => _isSaving = true);
    try {
      final Course? course = _course;
      final CourseCoins? coins = _coins;
      final RunLoad load = await _loadOf(record);
      final RunReward reward = await UserRepository.instance.saveRun(
        widget.userId,
        record,
        course: course == null || coins == null
            ? null
            : CourseResult.of(course.id, coins),
        load: load,
      );
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _tracker.reset();
        _coins = _freshCoins();
      });
      // 다 달렸으니 알림을 내립니다.
      _startGps(withForegroundService: false);
      final int felt = await showRunReport(context, record, reward, load);
      _saveFeltLoad(reward.runId, felt, load.level);
      if (widget.creatingCourse && mounted) await _offerToSaveCourse(record);
    } catch (e) {
      // 저장에 실패하면 기록을 그대로 두고 일시정지 상태로 두어 다시 시도할 수 있게 합니다.
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('기록 저장에 실패했어요. 인터넷 연결을 확인하고 다시 완료를 눌러주세요.');
    }
  }

  // 완료 창에서 고른 부하도를 기록에 적습니다. 실패해도 기록 자체는 이미 저장돼 있어서
  // 조용히 넘어갑니다. (계산값은 저장할 때 이미 들어갔습니다)
  void _saveFeltLoad(String? runId, int level, int computed) {
    if (runId == null) return;
    UserRepository.instance
        .saveFeltLoad(
          widget.userId,
          runId,
          level: level,
          computedLevel: computed,
        )
        .catchError((Object error) => debugPrint('부하도 저장 실패: $error'));
  }

  // 이번 러닝의 부하도. 역치 페이스를 지난 기록으로 추정해야 해서 기록을 한 번 읽습니다.
  // 못 읽으면(인터넷이 없을 때 등) 입문 기본값으로 계산합니다. 저장을 막지는 않습니다.
  Future<RunLoad> _loadOf(RunRecord record) async {
    List<Session> history = const [];
    try {
      final runs = await UserRepository.instance
          .watchRecentRuns(widget.userId, limit: UserRepository.maxStoredRuns)
          .first
          .timeout(const Duration(seconds: 5));
      history = [for (final log in runs) ?Session.fromLog(log)];
    } catch (error) {
      debugPrint('부하도 계산용 기록 읽기 실패: $error');
    }
    return RunLoad.of(record, history, now: DateTime.now());
  }

  // 방금 달린 길을 사설 코스로 올릴지 묻고, 이름을 받아 저장합니다.
  Future<void> _offerToSaveCourse(RunRecord record) async {
    final List<LatLng> path = Course.pathFromSegments(record.segments);
    if (record.distanceKm < Course.minUserCourseKm || path.length < 2) {
      _showMessage('${Course.minUserCourseKm}km 이상 달려야 코스로 만들 수 있어요.');
      return;
    }
    final String? district = (await SeoulDistricts.load()).districtAt(
      path.first,
    );
    if (!mounted) return;
    if (district == null) {
      _showMessage('서울 안에서 출발한 길만 코스로 만들 수 있어요.');
      return;
    }

    final String? name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _CourseNameDialog(district: district, km: record.distanceKm),
    );
    if (name == null || !mounted) return;

    try {
      final UserModel? me = await UserRepository.instance
          .watchUser(widget.userId)
          .first;
      await CourseRepository.instance.createUserCourse(
        userId: widget.userId,
        authorName: me?.nickname ?? '이름없음',
        name: name,
        district: district,
        segments: record.segments,
      );
      _showMessage('$district 사설 코스 "$name"을(를) 만들었어요.');
    } catch (error) {
      debugPrint('코스 만들기 실패: $error');
      _showMessage('코스를 저장하지 못했어요. 인터넷 연결을 확인해 주세요.');
    }
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {}); // build()에서 _stopwatch.elapsed를 다시 읽어옵니다.
    });
  }

  // 달리는 중에 뒤로 가기를 누르면 확인합니다.
  Future<void> _confirmExit() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('러닝을 그만둘까요?'),
        content: const Text('지금 나가면 이번 기록과 보상이 저장되지 않아요.\n저장하려면 [완료]를 눌러주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('기록 버리고 나가기'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 달리기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  // ----------------------------------------------------------
  // 개발용 시뮬레이터
  // ----------------------------------------------------------
  void _toggleSimulator() {
    final bool turningOn = !_useSimulator;

    if (turningOn) {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      // 시뮬레이터는 위치만 가짜로 움직입니다. 진짜 걸음은 생기지 않으므로
      // 걸음 센서를 꺼서, 거리로 걸음 수를 추정하게 해야 골드가 쌓입니다.
      _stepSubscription?.cancel();
      _stepSubscription = null;
      setState(() {
        _useSimulator = true;
        _tracker.disableStepSensor();
        // 조이스틱은 순간이동하듯 움직여서 속도 제한을 끕니다. (RunTracker.enforceSpeedLimit)
        _tracker.enforceSpeedLimit = false;
        // 코스 러닝이면 출발점에 세워서, 방향 버튼으로 바로 코스를 따라갈 수 있게 합니다.
        // 달리는 중에 옮기면 순간이동한 것처럼 기록되므로 시작 전에만 그렇게 합니다.
        final LatLng? courseStart = _tracker.state == RunState.idle
            ? _course?.points.first
            : null;
        _currentPosition = courseStart ?? _currentPosition ?? _defaultPosition;
      });
    } else {
      _stopSimulatorMove();
      setState(() {
        _useSimulator = false;
        _tracker.enforceSpeedLimit = true;
      });
      _startGps();
      _startStepSensor();
    }
  }

  void _startSimulatorMove(MoveDirection direction) {
    _moveSimulatorOneStep(direction);
    _simulatorTimer?.cancel();
    _simulatorTimer = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _moveSimulatorOneStep(direction),
    );
  }

  void _stopSimulatorMove() {
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
  }

  void _moveSimulatorOneStep(MoveDirection direction) {
    const double metersPerDegreeLat = 111320;
    final double metersPerDegreeLon =
        metersPerDegreeLat * cos(_position.latitude * pi / 180);
    final double dLat = _simulatorStepMeters / metersPerDegreeLat;
    final double dLon = _simulatorStepMeters / metersPerDegreeLon;

    final LatLng p = _position;
    final LatLng next = switch (direction) {
      MoveDirection.up => LatLng(p.latitude + dLat, p.longitude),
      MoveDirection.down => LatLng(p.latitude - dLat, p.longitude),
      MoveDirection.left => LatLng(p.latitude, p.longitude - dLon),
      MoveDirection.right => LatLng(p.latitude, p.longitude + dLon),
    };
    _onNewPosition(next);
  }

  // ----------------------------------------------------------
  // 코스
  // ----------------------------------------------------------
  // ⇄: 러닝이면 코스 고르기로, 코스 러닝이면 러닝으로. 화면을 바꿔 끼웁니다.
  // 바꾼 쪽을 기억해서, 다음에 홈에서 "시작"을 누르면 그 쪽으로 바로 갑니다.
  void _swap() {
    if (_tracker.state != RunState.idle) {
      _showMessage('달리는 중에는 바꿀 수 없어요. 완료한 뒤에 바꿔주세요.');
      return;
    }
    UserRepository.instance.setPrefersCourseRun(widget.userId, _course == null);
    final Widget next = _course == null
        ? CourseScreen(userId: widget.userId, position: _currentPosition)
        : RunScreen(userId: widget.userId);
    Navigator.pushReplacement(context, slideFromRight(next));
  }

  // 코스 출발점에서 멀리 떨어진 채 시작하면, 지도가 내 자리로 가면서 코스가
  // 화면 밖으로 사라져 버립니다. 왜 안 보이는지 알 수 있게 거리를 알려줍니다.
  void _warnIfFarFromCourse() {
    final Course? course = _course;
    if (course == null) return;
    final double meters = const Distance()(_position, course.points.first);
    if (meters > _farFromCourseMeters) {
      _showMessage(
        '코스 출발점에서 ${(meters / 1000).toStringAsFixed(1)}km 떨어져 있어요. '
        '코스 위를 지나야 코인을 먹어요.',
      );
    }
  }

  // 지도 위 코스 표시를 누르면 다른 코스를 고르러 갑니다.
  void _pickAnotherCourse() {
    if (_tracker.state != RunState.idle) return;
    Navigator.pushReplacement(
      context,
      slideFromRight(
        CourseScreen(
          userId: widget.userId,
          position: _currentPosition,
          selectedId: _course?.id,
        ),
      ),
    );
  }

  // 코스 전체가 화면에 들어오게 지도를 맞춥니다.
  void _showWholeCourse(Course course) {
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: course.points,
          padding: const EdgeInsets.all(48),
        ),
      );
    } catch (error) {
      debugPrint('코스 맞추기 실패: $error');
    }
  }

  // ----------------------------------------------------------
  // 나침반 / 숨은 개발자 모드
  // ----------------------------------------------------------
  // 한 번 누르면 지도를 북쪽이 위로 돌려놓고, 빠르게 6번이면 개발자 모드를 켜고 끕니다.
  void _onCompassTap() {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastCompassTap;
    if (last == null || now.difference(last) > _tapGap) _compassTaps = 0;
    _lastCompassTap = now;
    _compassTaps += 1;

    if (_compassTaps == 1) {
      try {
        _mapController.rotate(0);
      } catch (_) {}
    }
    if (_compassTaps >= _devModeTaps) {
      _compassTaps = 0;
      _toggleDevMode();
    }
  }

  void _toggleDevMode() {
    final bool turningOn = !_devMode;
    setState(() => _devMode = turningOn);
    // 방향 버튼이 보이면 위치도 방향 버튼으로 움직여야 합니다.
    if (turningOn != _useSimulator) _toggleSimulator();
    _showMessage(turningOn ? '개발자 모드를 켰어요.' : '개발자 모드를 껐어요.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tracker.state == RunState.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: RunAppBar(
          title: widget.creatingCourse
              ? '코스 만들기'
              : (_course == null ? '러닝' : '코스 러닝'),
          userId: widget.userId,
          onSwap: _swap,
        ),
        // 지도는 화면 끝까지 쓰고(top: false), 아래 패널만 시스템 영역을 피합니다.
        //
        // 기종에 따라 제스처 바나 내비게이션 바가 버튼을 덮는 일이 있어서,
        // SafeArea가 잡아주는 여백에 더해 최소 여백을 따로 줍니다.
        //
        // 아래 패널은 내용만큼만 높이를 쓰고, 지도가 나머지를 전부 가져갑니다.
        // 그래야 보통 기종에서는 패널을 스크롤할 일이 없습니다. 화면이 아주 작은
        // 기종에서만 패널이 화면의 62%에서 멈추고 숫자 부분이 스크롤됩니다.
        body: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                Expanded(child: SafeArea(bottom: false, child: _buildMap())),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.62,
                  ),
                  child: _buildPanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _position,
            initialZoom: _initialZoom,
            onMapReady: () {
              _isMapReady = true;
              // 코스를 들고 들어왔으면 코스 전체부터 보여줍니다.
              final Course? course = _course;
              if (course != null) _showWholeCourse(course);
            },
          ),
          children: [
            ...MapTiles.layers(),
            // 고른 코스는 절취선 같은 점선으로 깔아 둡니다. 반투명이지만 진해서 색을 뺀
            // 지도 위에서도 또렷하고, 그 위를 지나간 내 경로(검은 실선)와 구분됩니다.
            if (_course != null) ...[
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _course!.points,
                    strokeWidth: 5,
                    color: AppColors.black.withValues(alpha: 0.6),
                    pattern: StrokePattern.dashed(segments: const [14, 9]),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  ..._coinMarkers(),
                  Marker(
                    point: _course!.points.last,
                    width: 22,
                    height: 22,
                    child: const _CourseFlag(finish: true),
                  ),
                  Marker(
                    point: _course!.points.first,
                    width: 22,
                    height: 22,
                    child: const _CourseFlag(finish: false),
                  ),
                ],
              ),
            ],
            PolylineLayer(
              polylines: [
                // 토막마다 따로 긋습니다. 신호가 끊겼던 구간이 직선으로 이어지지 않습니다.
                for (final segment in _tracker.segments)
                  if (segment.length >= 2)
                    Polyline(
                      points: segment,
                      strokeWidth: 4,
                      // 색을 뺀 지도 위라 먹색 선이 가장 또렷합니다. 어두운 길 위에서도
                      // 묻히지 않게 바깥에 흰 테두리를 얇게 두릅니다.
                      color: AppColors.black,
                      borderStrokeWidth: 1.5,
                      borderColor: AppColors.white,
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _position,
                  width: 24,
                  height: 24,
                  child: const _PositionDot(),
                ),
              ],
            ),
          ],
        ),
        // 진단 줄은 지도 위에 얹습니다. 아래 패널에 넣으면 화면이 좁아서 잘립니다.
        if (_devMode)
          Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: _GpsDiagnostics(
              fixCount: _fixCount,
              lastFixAt: _lastFixAt,
              lastAccuracy: _lastAccuracy,
              droppedByAccuracy: _droppedByAccuracy,
              rejectedJumps: _tracker.rejectedJumps,
              tooFastCount: _tracker.tooFastCount,
              segments: _tracker.segments,
              isStreaming: _positionSubscription != null,
              isSimulator: _useSimulator,
              usingForegroundService: _usingForegroundService,
              streamError: _streamError,
              hasFix: _currentPosition != null,
            ),
          ),
        if (_course != null)
          Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.md,
            right: _devMode ? 160 : 72,
            child: _CourseChip(
              course: _course!,
              coins: _coins,
              onTap: _pickAnotherCourse,
            ),
          ),
        if (widget.creatingCourse)
          Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.md,
            right: _devMode ? 160 : 72,
            child: const _CreatingCourseChip(),
          ),
        // 나침반. 개발자 모드에서는 방향 버튼 한가운데로 들어갑니다.
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _devMode
              ? _SimulatorPad(
                  onPressStart: _startSimulatorMove,
                  onPressEnd: _stopSimulatorMove,
                  center: _Compass(onTap: _onCompassTap),
                )
              : _Compass(onTap: _onCompassTap),
        ),
      ],
    );
  }

  // 아직 안 먹은 코인. 왕복 코스에서 반환점을 찍기 전에는 흐리게 보여서
  // "지금은 못 먹는다"를 알려줍니다.
  List<Marker> _coinMarkers() {
    final CourseCoins? coins = _coins;
    if (coins == null) return const [];
    final bool locked = coins.isRoundTrip && !coins.turned;
    final LatLng? turn = coins.turnPoint;
    return [
      for (int i = 0; i < coins.coins.length; i++)
        if (!coins.isCollected(i))
          Marker(
            point: coins.coins[i],
            width: 18,
            height: 18,
            child: Opacity(
              opacity: locked ? 0.5 : 1,
              child: const GoldCoin(size: 18),
            ),
          ),
      if (turn != null && !coins.turned)
        Marker(point: turn, width: 24, height: 24, child: const _TurnMark()),
    ];
  }

  Widget _buildPanel() {
    final RunRecord record = _tracker.record;

    return SafeArea(
      top: false,
      // minimum: 시스템 여백이 0이거나 아주 작은 기종에서도 이만큼은 띄웁니다.
      // 이게 없으면 제스처 바 위에 버튼이 바싹 붙거나 가려집니다.
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppTheme.bottomButtonGap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 숫자들은 자리가 모자라면 스크롤되게 둡니다.
          //
          // 예전에는 여기가 전부 한 Column이어서, 화면이 작은 기종에서는 내용이
          // 패널 높이를 넘어가고 넘친 만큼 아래로 삐져나가 버튼이 내비게이션 바에
          // 가려졌습니다. 버튼을 바깥에 따로 두면 그럴 수가 없습니다.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 메인 숫자: 러닝 시간
                  Text(
                    formatDuration(record.elapsed),
                    style: AppTheme.number.copyWith(fontSize: 52),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('ELAPSED TIME', style: AppTheme.caption),
                  const SizedBox(height: AppSpacing.md),

                  const DoubleRule(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TotalBlock(
                              value: formatKm(record.distanceMeters),
                              label: '킬로미터',
                              center: true,
                            ),
                          ),
                          const VerticalDivider(
                            color: AppColors.sand,
                            width: 1,
                          ),
                          Expanded(
                            child: TotalBlock(
                              value: '${record.steps}',
                              label: '걸음',
                              center: true,
                            ),
                          ),
                          const VerticalDivider(
                            color: AppColors.sand,
                            width: 1,
                          ),
                          Expanded(
                            child: TotalBlock(
                              value: formatPace(record.paceMinPerKm),
                              label: '평균 페이스',
                              center: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const DoubleRule(),

                  const SizedBox(height: AppSpacing.md),
                  _RewardPreview(
                    userId: widget.userId,
                    record: record,
                    coins: _coins,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    if (_isSaving) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_tracker.state) {
      case RunState.idle:
        return _RunButton(label: '시작', onTap: _start);
      case RunState.running:
        return Row(
          children: [
            Expanded(
              child: _RunButton(
                label: '일시정지',
                icon: Icons.pause,
                onTap: _pause,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _RunButton(
                label: '완료',
                icon: Icons.stop,
                filled: false,
                onTap: _finish,
              ),
            ),
          ],
        );
      case RunState.paused:
        return Row(
          children: [
            Expanded(
              child: _RunButton(
                label: '재개',
                icon: Icons.play_arrow,
                onTap: _resume,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _RunButton(
                label: '완료',
                icon: Icons.stop,
                filled: false,
                onTap: _finish,
              ),
            ),
          ],
        );
    }
  }
}

// ------------------------------------------------------------
// 작은 위젯들
// ------------------------------------------------------------

// 러닝 화면 아래 버튼. 홈의 "시작" 버튼과 같은 둥근 모양입니다.
class _RunButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final VoidCallback onTap;

  const _RunButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color background = filled ? AppColors.black : AppColors.white;
    final Color foreground = filled ? AppColors.white : AppColors.black;

    final Widget body = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: foreground),
        ),
      ],
    );

    // 검은 버튼은 안쪽에 흰 테두리를 한 겹, 흰 버튼은 바깥에 검은 테두리를 그립니다.
    // 두 버튼의 높이가 같도록 흰 버튼은 그만큼 안쪽 여백을 더 줍니다.
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: filled
            ? BorderSide.none
            : const BorderSide(color: AppColors.black, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: filled
            ? Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.white, width: 1.2),
                  borderRadius: BorderRadius.circular(AppRadius.md - 6),
                ),
                child: body,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md + 6,
                ),
                child: body,
              ),
      ),
    );
  }
}

// 달리는 중 "지금까지 얻은 보상" 미리보기
// 완료 리포트와 숫자가 어긋나지 않도록, 입고 있는 장비 보너스까지 반영해서 보여줍니다.
// 이 화면은 1초마다 다시 그려지므로 스트림은 State에 한 번만 만들어 둡니다.
class _RewardPreview extends StatefulWidget {
  final String userId;
  final RunRecord record;

  // 코스 러닝이면 골드를 걸음이 아니라 코인으로 셉니다. 저장할 때와 같은 계산입니다.
  final CourseCoins? coins;

  const _RewardPreview({
    required this.userId,
    required this.record,
    required this.coins,
  });

  @override
  State<_RewardPreview> createState() => _RewardPreviewState();
}

class _RewardPreviewState extends State<_RewardPreview> {
  late final Stream<UserModel?> _userStream = UserRepository.instance.watchUser(
    widget.userId,
  );

  int _gold(EquipmentSet? gear) {
    final CourseCoins? coins = widget.coins;
    return coins == null
        ? RunRules.goldFor(widget.record, gear: gear)
        : RunRules.courseGoldFor(coins.gold, gear: gear);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final RunRecord record = widget.record;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Text('움직인 시간 ', style: textTheme.labelMedium),
          Text(formatDuration(record.movingTime), style: textTheme.titleMedium),
          const Spacer(),
          StreamBuilder<UserModel?>(
            stream: _userStream,
            builder: (context, snapshot) {
              final UserModel? user = snapshot.data;
              final EquipmentSet? gear = user == null
                  ? null
                  : EquipmentRules.equippedSet(user);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${RunRules.expFor(record, gear: gear)} EXP  ·  '
                    '+${_gold(gear)} ',
                    style: textTheme.titleMedium,
                  ),
                  const GoldCoin(size: 16),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// 개발 빌드에만 보이는 GPS 진단 줄 (지도 왼쪽 위)
//
// "경로가 안 그려진다"를 숫자로 바꿔서 보여줍니다. 어디서 막혔는지 바로 알 수 있습니다.
//   수신 0            -> 위치가 아예 안 들어옴 (권한/서비스 문제)
//   수신은 느는데 버림만 늘면 -> 오차가 커서 다 걸러지는 중
//   화면을 끄고 돌아왔을 때 "마지막"이 몇 분 전이면 -> 백그라운드에서 끊긴 것
//   토막이 여러 개인데 점이 적으면 -> 신호가 자주 끊겨서 선이 계속 끊기는 중
class _GpsDiagnostics extends StatelessWidget {
  final int fixCount;
  final DateTime? lastFixAt;
  final double? lastAccuracy;
  final int droppedByAccuracy;
  final int rejectedJumps;
  final int tooFastCount;
  final List<List<LatLng>> segments;
  final bool isStreaming;
  final bool isSimulator;
  final bool usingForegroundService;
  final String? streamError;
  final bool hasFix;

  const _GpsDiagnostics({
    required this.fixCount,
    required this.lastFixAt,
    required this.lastAccuracy,
    required this.droppedByAccuracy,
    required this.rejectedJumps,
    required this.tooFastCount,
    required this.segments,
    required this.isStreaming,
    required this.isSimulator,
    required this.usingForegroundService,
    required this.streamError,
    required this.hasFix,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime? last = lastFixAt;
    final String since = last == null
        ? '없음'
        : '${DateTime.now().difference(last).inSeconds}초 전';
    final String accuracy = lastAccuracy == null
        ? '-'
        : '${lastAccuracy!.toStringAsFixed(0)}m';

    final bool stale =
        last != null && DateTime.now().difference(last).inSeconds > 30;
    final int points = segments.fold(0, (sum, s) => sum + s.length);
    final int drawable = segments.where((s) => s.length >= 2).length;

    // 한눈에 정상/비정상이 보이도록 색을 바꿉니다.
    final bool healthy =
        streamError == null && (isSimulator || (isStreaming && fixCount > 0));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: (healthy ? AppColors.black : Colors.red).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: DefaultTextStyle(
        // DefaultTextStyle은 위에서 내려오는 글꼴을 버리고 새로 정하므로 글꼴을 적습니다.
        style: const TextStyle(
          fontFamily: AppTheme.sansFont,
          color: AppColors.white,
          fontSize: 11,
          height: 1.35,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSimulator
                  ? '조이스틱 모드'
                  : '스트림 ${isStreaming ? "켜짐" : "꺼짐"}  ·  수신 $fixCount회  ·  마지막 $since  ·  오차 $accuracy',
            ),
            Text(
              '점 $points개  ·  토막 ${segments.length}개(그려지는 것 $drawable)  ·  '
              '오차로 버림 $droppedByAccuracy  ·  멀어서 버림 $rejectedJumps  ·  빨라서 버림 $tooFastCount',
            ),
            if (!isSimulator)
              Text(
                '백그라운드 기록 ${usingForegroundService ? "켜짐" : "꺼짐"}  ·  '
                '내 위치 ${hasFix ? "잡힘" : "아직"}',
              ),
            // 5m 이상 움직여야 다음 위치가 옵니다(distanceFilter). 서 있으면 수신이 멈춘
            // 것처럼 보이는데 고장이 아니라서, 오해하지 않도록 적어둡니다.
            if (!isSimulator && fixCount > 0 && stale)
              const Text('가만히 있으면 안 옵니다. 5m 이상 움직여 보세요.'),
            if (streamError != null)
              Text(
                '오류: $streamError',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: AppTheme.sansMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 지도 위 내 위치 점
class _PositionDot extends StatelessWidget {
  const _PositionDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.black,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 4),
      ),
    );
  }
}

// 지도 위 코스 출발(흰 점)/도착(검은 점)
class _CourseFlag extends StatelessWidget {
  final bool finish;

  const _CourseFlag({required this.finish});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: finish ? AppColors.black : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.black, width: 2),
      ),
      child: Icon(
        finish ? Icons.flag : Icons.play_arrow,
        size: 12,
        color: finish ? AppColors.white : AppColors.black,
      ),
    );
  }
}

// 코스 만들기 중이라는 표시 (지도 왼쪽 아래)
class _CreatingCourseChip extends StatelessWidget {
  const _CreatingCourseChip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 4,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          '코스 만들기 · 달린 길이 사설 코스가 됩니다',
          overflow: TextOverflow.ellipsis,
          style: AppTheme.sans.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

// 사설 코스 이름 받기. 비우거나 너무 길면 만들기를 누를 수 없습니다.
class _CourseNameDialog extends StatefulWidget {
  final String district;
  final double km;

  const _CourseNameDialog({required this.district, required this.km});

  @override
  State<_CourseNameDialog> createState() => _CourseNameDialogState();
}

class _CourseNameDialogState extends State<_CourseNameDialog> {
  static const int maxLength = 16;
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('사설 코스로 만들까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.district} · ${widget.km.toStringAsFixed(2)}km',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: maxLength,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '코스 이름 (예: 아침 당현천)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('그만두기'),
        ),
        ElevatedButton(
          onPressed: _trimmed.isEmpty
              ? null
              : () => Navigator.pop(context, _trimmed),
          child: const Text('만들기'),
        ),
      ],
    );
  }
}

// 왕복 코스의 반환점. 여기를 찍어야 코인을 먹기 시작합니다.
class _TurnMark extends StatelessWidget {
  const _TurnMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.black,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: const Icon(Icons.u_turn_left, size: 14, color: AppColors.white),
    );
  }
}

// 지도 왼쪽 아래: 지금 고른 코스 이름과 먹은 코인 수 (누르면 다른 코스 고르기)
class _CourseChip extends StatelessWidget {
  final Course course;
  final CourseCoins? coins;
  final VoidCallback onTap;

  const _CourseChip({
    required this.course,
    required this.coins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md - 4,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${course.name} · ${formatKm(course.distanceMeters)}km',
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.white,
                  ),
                ),
              ),
              if (coins != null) ...[
                const SizedBox(width: AppSpacing.sm),
                const GoldCoin(size: 15),
                Text(
                  ' ${coins!.collectedCount}/${coins!.coins.length}',
                  style: AppTheme.sans.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.sandOnDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// 나침반. 폰의 방향 센서를 읽어서 바늘이 실제 북쪽을 가리킵니다.
// 폰을 돌리면 바늘이 반대로 돌아 북쪽에 머뭅니다.
//
// 센서가 없는 기종(일부 저가폰, 에뮬레이터)에서는 바늘이 위를 향한 채 멈춰 있고
// 가운데 점이 빈 원으로 바뀝니다.
class _Compass extends StatefulWidget {
  final VoidCallback onTap;

  const _Compass({required this.onTap});

  @override
  State<_Compass> createState() => _CompassState();
}

class _CompassState extends State<_Compass> {
  StreamSubscription<CompassEvent>? _subscription;
  bool _hasSensor = false;

  // AnimatedRotation에 넘기는 바퀴 수. 359도 -> 1도로 넘어갈 때 한 바퀴 거꾸로 돌지
  // 않도록, 각도를 그대로 쓰지 않고 가까운 쪽으로 이어 붙입니다.
  double _turns = 0;

  @override
  void initState() {
    super.initState();
    _subscription = FlutterCompass.events?.listen(
      _onHeading,
      onError: (Object error) => debugPrint('나침반 오류: $error'),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onHeading(CompassEvent event) {
    final double? heading = event.heading;
    if (heading == null || !mounted) return;
    // 폰이 동쪽(90도)을 보면 북쪽은 화면 왼쪽(-90도)입니다.
    final double target = -heading / 360;
    final double delta = target - _turns;
    final double shortest = delta - delta.roundToDouble();
    // 1도 미만 흔들림은 무시합니다. 매번 다시 그리면 배터리만 씁니다.
    if (_hasSensor && shortest.abs() < 1 / 360) return;
    setState(() {
      _hasSensor = true;
      _turns += shortest;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.black, width: 1.4),
        ),
        child: AnimatedRotation(
          turns: _turns,
          duration: const Duration(milliseconds: 180),
          child: CustomPaint(painter: _NeedlePainter(hasSensor: _hasSensor)),
        ),
      ),
    );
  }
}

// 위쪽 검은 바늘(북) + 아래쪽 옅은 바늘(남)
class _NeedlePainter extends CustomPainter {
  final bool hasSensor;

  const _NeedlePainter({required this.hasSensor});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    const double length = 13;
    const double half = 4.5;
    final Path north = Path()
      ..moveTo(c.dx, c.dy - length)
      ..lineTo(c.dx + half, c.dy)
      ..lineTo(c.dx - half, c.dy)
      ..close();
    final Path south = Path()
      ..moveTo(c.dx, c.dy + length)
      ..lineTo(c.dx + half, c.dy)
      ..lineTo(c.dx - half, c.dy)
      ..close();
    canvas.drawPath(south, Paint()..color = AppColors.sand);
    canvas.drawPath(north, Paint()..color = AppColors.black);
    // 센서가 없으면 가운데를 빈 원으로 그려서 "진짜 방향이 아님"을 알립니다.
    canvas.drawCircle(
      c,
      hasSensor ? 1.6 : 2.6,
      Paint()
        ..color = AppColors.white
        ..style = hasSensor ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) =>
      oldDelegate.hasSensor != hasSensor;
}

// 개발용 방향 버튼 (누르고 있는 동안 계속 이동)
class _SimulatorPad extends StatelessWidget {
  final void Function(MoveDirection) onPressStart;
  final VoidCallback onPressEnd;

  // 가운데 빈칸에 넣을 것 (나침반)
  final Widget center;

  const _SimulatorPad({
    required this.onPressStart,
    required this.onPressEnd,
    required this.center,
  });

  Widget _button(IconData icon, MoveDirection direction) {
    return GestureDetector(
      onTapDown: (_) => onPressStart(direction),
      onTapUp: (_) => onPressEnd(),
      onTapCancel: onPressEnd,
      child: Container(
        margin: const EdgeInsets.all(2),
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.black,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(Icons.keyboard_arrow_up, MoveDirection.up),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(Icons.keyboard_arrow_left, MoveDirection.left),
            SizedBox(width: 48, height: 48, child: Center(child: center)),
            _button(Icons.keyboard_arrow_right, MoveDirection.right),
          ],
        ),
        _button(Icons.keyboard_arrow_down, MoveDirection.down),
      ],
    );
  }
}
