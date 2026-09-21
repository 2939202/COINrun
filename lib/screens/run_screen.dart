import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../game/run_rules.dart';
import '../models/run_record.dart';
import '../models/user_model.dart';
import '../services/location_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/stat_block.dart';

// ============================================================
// RunScreen: 지도 + 러닝 기록 화면
//
// 흐름: 시작 전(idle) -> 달리는 중(running) <-> 일시정지(paused) -> 완료
//   - 완료를 누르면 UserRepository가 보상을 계산해 Firestore에 저장하고,
//     완료 리포트를 보여줍니다.
//   - 개발 모드(kDebugMode)에서만 밖에 나가지 않고 시험할 수 있는
//     시뮬레이터(방향 버튼)를 켤 수 있습니다. 출시 버전에는 보이지 않습니다.
// ============================================================

enum RunState { idle, running, paused }

enum MoveDirection { up, down, left, right }

class RunScreen extends StatefulWidget {
  final String userId;

  const RunScreen({super.key, required this.userId});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  static const LatLng _defaultPosition = LatLng(37.5665, 126.9780); // 서울 시청
  static const double _zoom = 17;

  // 위치
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _currentPosition; // 아직 GPS를 못 받았으면 null

  // 러닝 세션
  RunState _runState = RunState.idle;
  final Stopwatch _stopwatch = Stopwatch(); // 일시정지 후 재개해도 시간이 이어집니다.
  Timer? _uiTimer; // 1초마다 화면을 다시 그리기만 하는 타이머
  double _distance = 0; // 이번 러닝 거리 (m)
  List<LatLng> _path = [];
  bool _isSaving = false;

  // 개발용 시뮬레이터
  bool _useSimulator = false;
  Timer? _simulatorTimer;
  static const double _simulatorStepMeters = 5;

  LatLng get _position => _currentPosition ?? _defaultPosition;

  RunRecord get _record =>
      RunRecord(elapsed: _stopwatch.elapsed, distanceMeters: _distance);

  @override
  void initState() {
    super.initState();
    // 시작 전에도 지도에 내 위치가 보이도록 바로 GPS를 켭니다.
    _startGps();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _uiTimer?.cancel();
    _simulatorTimer?.cancel();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 위치 수신
  // ----------------------------------------------------------
  Future<void> _startGps() async {
    final String? error = await LocationService.ensurePermission();
    if (error != null) {
      _showMessage(error);
      return;
    }
    if (!mounted || _useSimulator) return;

    await _positionSubscription?.cancel();
    _positionSubscription = LocationService.positionStream().listen(
      (position) {
        // 오차가 큰 위치는 버립니다 (GPS 흔들림 때문에 거리가 쌓이는 것 방지)
        if (position.accuracy > LocationService.maxAccuracyMeters) return;
        _onNewPosition(LatLng(position.latitude, position.longitude));
      },
      onError: (Object error) {
        // 터널, 건물 사이 등에서 잠깐 신호를 놓치는 오류는 무시하고 다음 위치를 기다립니다.
        // (onError가 없으면 처리되지 않은 오류로 앱에 쌓입니다)
        debugPrint('GPS 오류: $error');
      },
    );
  }

  // GPS든 시뮬레이터든 새 위치는 모두 여기로 들어옵니다.
  void _onNewPosition(LatLng newPosition) {
    final LatLng? previous = _currentPosition;

    setState(() {
      _currentPosition = newPosition;
      // 달리는 중일 때만 거리와 경로를 기록합니다.
      if (_runState == RunState.running) {
        if (previous != null) {
          _distance += LocationService.distanceBetween(
            previous.latitude,
            previous.longitude,
            newPosition.latitude,
            newPosition.longitude,
          );
        }
        _path.add(newPosition);
      }
    });

    _mapController.move(newPosition, _zoom);
  }

  // ----------------------------------------------------------
  // 러닝 세션 (시작 / 일시정지 / 재개 / 완료)
  // ----------------------------------------------------------
  void _start() {
    setState(() {
      _runState = RunState.running;
      _distance = 0;
      _path = [_position];
    });
    _stopwatch
      ..reset()
      ..start();
    _startUiTimer();
  }

  void _pause() {
    _stopwatch.stop();
    _uiTimer?.cancel();
    setState(() => _runState = RunState.paused);
  }

  void _resume() {
    _stopwatch.start();
    _startUiTimer();
    setState(() => _runState = RunState.running);
  }

  Future<void> _finish() async {
    _stopwatch.stop();
    _uiTimer?.cancel();
    final RunRecord record = _record; // 초기화하기 전에 최종 기록을 담아둡니다.

    setState(() => _isSaving = true);
    try {
      final RunReward reward = await UserRepository.instance.saveRun(
        widget.userId,
        record,
      );
      if (!mounted) return;

      setState(() {
        _runState = RunState.idle;
        _isSaving = false;
        _distance = 0;
        _path = [];
      });
      _stopwatch.reset();
      _showReport(record, reward);
    } catch (e) {
      // 저장에 실패하면 기록을 그대로 두고 일시정지 상태로 돌려서 다시 시도할 수 있게 합니다.
      if (!mounted) return;
      setState(() {
        _runState = RunState.paused;
        _isSaving = false;
      });
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
    setState(() => _useSimulator = !_useSimulator);
    if (_useSimulator) {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _currentPosition ??= _defaultPosition;
    } else {
      _stopSimulatorMove();
      _startGps();
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
      canPop: _runState == RunState.idle,
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
          options: MapOptions(initialCenter: _position, initialZoom: _zoom),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.contact',
            ),
            PolylineLayer(
              polylines: [
                if (_path.length >= 2)
                  Polyline(
                    points: _path,
                    strokeWidth: 6,
                    color: AppColors.black,
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
    final RunRecord record = _record;

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
              StatBlock(
                value: formatPace(record.paceMinPerKm),
                label: '평균 페이스',
              ),
              StatBlock(
                value: record.calories.toStringAsFixed(0),
                label: '칼로리',
              ),
            ],
          ),
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

    switch (_runState) {
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

  // 러닝 완료 리포트
  void _showReport(RunRecord record, RunReward reward) {
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('러닝 완료', style: textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  StatBlock(
                    value: formatKm(record.distanceMeters),
                    label: '킬로미터',
                  ),
                  StatBlock(value: formatDuration(record.elapsed), label: '시간'),
                  StatBlock(
                    value: formatPace(record.paceMinPerKm),
                    label: '평균 페이스',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  StatBlock(value: '+${reward.gold}', label: '골드'),
                  StatBlock(value: '+${reward.exp}', label: '경험치'),
                  StatBlock(value: 'Lv.${reward.levelAfter}', label: '레벨'),
                ],
              ),
              if (reward.leveledUp) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.volt,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '레벨 업! Lv.${reward.levelAfter} · '
                    '${RunRules.tierName(reward.levelAfter)}',
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 작은 위젯들
// ------------------------------------------------------------

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
