import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../game/equipment_rules.dart';
import '../game/run_rules.dart';
import '../game/run_tracker.dart';
import '../models/equipment_set.dart';
import '../models/run_record.dart';
import '../models/user_model.dart';
import '../services/location_service.dart';
import '../services/step_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/stat_block.dart';
import 'run_report.dart';

// ============================================================
// RunScreen: 지도 + 러닝 기록 화면
//
// 흐름: 시작 전(idle) -> 달리는 중(running) <-> 일시정지(paused) -> 완료
//   - 완료를 누르면 UserRepository가 보상을 계산해 Firestore에 저장하고,
//     완료 리포트를 보여줍니다.
//   - 개발 모드(kDebugMode)에서만 밖에 나가지 않고 시험할 수 있는
//     시뮬레이터(방향 버튼)를 켤 수 있습니다. 출시 버전에는 보이지 않습니다.
// ============================================================

enum MoveDirection { up, down, left, right }

class RunScreen extends StatefulWidget {
  final String userId;

  const RunScreen({super.key, required this.userId});

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

  // 개발용 시뮬레이터
  bool _useSimulator = false;
  Timer? _simulatorTimer;
  static const double _simulatorStepMeters = 5;

  LatLng get _position => _currentPosition ?? _defaultPosition;

  @override
  void initState() {
    super.initState();
    // 스트림은 이 화면에 들어올 때 딱 한 번, 포그라운드 설정을 넣어서 엽니다.
    //
    // 시작을 누를 때 다시 여는 방식은 쓰지 않습니다. geolocator는 이미 열린 스트림이
    // 있으면 새 설정을 무시하고 그걸 돌려주기 때문에(geolocator_android.dart:167),
    // 두 번 여는 순간 설정이 먹었는지 안 먹었는지 알 수 없게 됩니다.
    // 스트림이 첫 위치를 줄 때까지 기다리지 않도록, 폰이 이미 알고 있는 위치를
    // 먼저 지도에 찍어둡니다. (스트림은 5m를 움직여야 첫 값을 줍니다)
    _showLastKnownPosition();
    _startGps();
    _startStepSensor();
    // 러닝 중 알림을 보여주기 위한 권한 (안드로이드 13 이상).
    // 거부해도 기록은 정상으로 됩니다. 알림만 안 보입니다.
    LocationService.requestNotificationPermission();
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
  Future<void> _startGps({bool withForegroundService = true}) async {
    final String? error = await LocationService.ensurePermission();
    if (error != null) {
      if (mounted) setState(() => _streamError = error);
      _showMessage(error);
      return;
    }
    await LocationService.requestNotificationPermission();
    if (!mounted || _useSimulator) return;

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    setState(() {
      _usingForegroundService = withForegroundService;
      _streamError = null;
    });

    _positionSubscription =
        LocationService.positionStream(
          keepAliveInBackground: withForegroundService,
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

    _startWatchdog(withForegroundService);
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
  }

  // 내 위치를 화면 가운데에 둡니다. 배율은 지금 화면에 맞춰진 값을 그대로 씁니다.
  // (예전에는 _initialZoom을 넘겨서, 손으로 확대해도 다음 위치가 들어오는 순간
  //  원래 배율로 되돌아갔습니다)
  //
  // 지도 조작이 실패해도 기록은 계속돼야 합니다. 화면을 끈 동안에는 지도가 그려지지
  // 않는데, 그때 오류가 나서 거리와 경로까지 멈추면 안 됩니다.
  void _moveMap(LatLng position) {
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
    final bool granted = await StepService.ensurePermission();
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
    });
    _startUiTimer();
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
      final RunReward reward = await UserRepository.instance.saveRun(
        widget.userId,
        record,
      );
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _tracker.reset();
      });
      showRunReport(context, record, reward);
    } catch (e) {
      // 저장에 실패하면 기록을 그대로 두고 일시정지 상태로 두어 다시 시도할 수 있게 합니다.
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('기록 저장에 실패했어요. 인터넷 연결을 확인하고 다시 완료를 눌러주세요.');
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
        _currentPosition ??= _defaultPosition;
      });
    } else {
      _stopSimulatorMove();
      setState(() => _useSimulator = false);
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
        appBar: AppBar(
          title: const Text('러닝'),
          actions: [
            _UserBadge(userId: widget.userId),
            if (kDebugMode)
              IconButton(
                tooltip: '시뮬레이터 (개발용)',
                onPressed: _toggleSimulator,
                icon: Icon(
                  _useSimulator ? Icons.gamepad : Icons.gamepad_outlined,
                ),
              ),
            const SizedBox(width: AppSpacing.md),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(flex: 55, child: _buildMap()),
              Expanded(flex: 45, child: _buildPanel()),
            ],
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
            onMapReady: () => _isMapReady = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.contact',
            ),
            PolylineLayer(
              polylines: [
                // 토막마다 따로 긋습니다. 신호가 끊겼던 구간이 직선으로 이어지지 않습니다.
                for (final segment in _tracker.segments)
                  if (segment.length >= 2)
                    Polyline(
                      points: segment,
                      strokeWidth: 3.5,
                      // 지도 도로선과 섞이지 않도록 형광색에 검은 테두리를 둘러 그립니다.
                      color: AppColors.volt,
                      borderStrokeWidth: 1.5,
                      borderColor: AppColors.black,
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
        if (kDebugMode)
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
              segments: _tracker.segments,
              isStreaming: _positionSubscription != null,
              isSimulator: _useSimulator,
              usingForegroundService: _usingForegroundService,
              streamError: _streamError,
              hasFix: _currentPosition != null,
            ),
          ),
        if (_useSimulator)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _SimulatorPad(
              onPressStart: _startSimulatorMove,
              onPressEnd: _stopSimulatorMove,
            ),
          ),
      ],
    );
  }

  Widget _buildPanel() {
    final textTheme = Theme.of(context).textTheme;
    final RunRecord record = _tracker.record;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          // 메인 숫자: 러닝 시간
          Text(formatDuration(record.elapsed), style: textTheme.displayLarge),
          Text('시간', style: textTheme.labelMedium),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              StatBlock(value: formatKm(record.distanceMeters), label: '킬로미터'),
              StatBlock(value: '${record.steps}', label: '걸음'),
              StatBlock(
                value: formatPace(record.paceMinPerKm),
                label: '평균 페이스',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _RewardPreview(userId: widget.userId, record: record),
          const Spacer(),
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
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: _start, child: const Text('시작')),
        );
      case RunState.running:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pause,
                icon: const Icon(Icons.pause),
                label: const Text('일시정지'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.stop),
                label: const Text('완료'),
              ),
            ),
          ],
        );
      case RunState.paused:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _resume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('재개'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.volt,
                  foregroundColor: AppColors.black,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.stop),
                label: const Text('완료'),
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

// 달리는 중 "지금까지 얻은 보상" 미리보기
// 완료 리포트와 숫자가 어긋나지 않도록, 입고 있는 장비 보너스까지 반영해서 보여줍니다.
// 이 화면은 1초마다 다시 그려지므로 스트림은 State에 한 번만 만들어 둡니다.
class _RewardPreview extends StatefulWidget {
  final String userId;
  final RunRecord record;

  const _RewardPreview({required this.userId, required this.record});

  @override
  State<_RewardPreview> createState() => _RewardPreviewState();
}

class _RewardPreviewState extends State<_RewardPreview> {
  late final Stream<UserModel?> _userStream = UserRepository.instance.watchUser(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final RunRecord record = widget.record;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
              return Text(
                '+${RunRules.expFor(record, gear: gear)} EXP  ·  '
                '+${RunRules.goldFor(record, gear: gear)} G',
                style: textTheme.titleMedium,
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
        style: const TextStyle(
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
              '오차로 버림 $droppedByAccuracy  ·  멀어서 버림 $rejectedJumps',
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
                  color: AppColors.volt,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 앱바 오른쪽의 레벨/골드 표시 (Firestore 값을 실시간으로 보여줌)
// 러닝 화면은 1초마다 다시 그려지므로, 스트림을 State에 한 번만 만들어 둡니다.
class _UserBadge extends StatefulWidget {
  final String userId;

  const _UserBadge({required this.userId});

  @override
  State<_UserBadge> createState() => _UserBadgeState();
}

class _UserBadgeState extends State<_UserBadge> {
  late final Stream<UserModel?> _userStream = UserRepository.instance.watchUser(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, snapshot) {
        final UserModel? user = snapshot.data;
        if (user == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'Lv.${user.level} · ${user.gold} G',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 13),
          ),
        );
      },
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
        border: Border.all(color: AppColors.volt, width: 4),
      ),
    );
  }
}

// 개발용 방향 버튼 (누르고 있는 동안 계속 이동)
class _SimulatorPad extends StatelessWidget {
  final void Function(MoveDirection) onPressStart;
  final VoidCallback onPressEnd;

  const _SimulatorPad({required this.onPressStart, required this.onPressEnd});

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
            const SizedBox(width: 44),
            _button(Icons.keyboard_arrow_right, MoveDirection.right),
          ],
        ),
        _button(Icons.keyboard_arrow_down, MoveDirection.down),
      ],
    );
  }
}
