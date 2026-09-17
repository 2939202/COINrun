import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ------------------------------------------------------------
// Haversine 공식 - 두 좌표 사이의 거리를 미터 단위로 계산
// ------------------------------------------------------------
double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    ) {
  const double earthRadius = 6371000; // 지구 반지름 (미터)

  final double lat1Rad = _degreesToRadians(lat1);
  final double lat2Rad = _degreesToRadians(lat2);
  final double deltaLat = _degreesToRadians(lat2 - lat1);
  final double deltaLon = _degreesToRadians(lon2 - lon1);

  final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

double _degreesToRadians(double degrees) => degrees * (pi / 180);

// 조이스틱 방향 enum
enum MoveDirection { up, down, left, right }

// ------------------------------------------------------------
// RunScreen: 지도 + GPS + 조이스틱 통합 달리기 화면
// ------------------------------------------------------------
class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  // GPS 및 디버그 상태 변수
  bool isDebugMode = true;
  double totalDistance = 0.0;
  Position? lastPosition;
  StreamSubscription<Position>? positionStreamSubscription;

  // 가상 GPS 좌표 (서울 과학기술대/하계 부근 기준)
  double debugLat = 37.64898844354454;
  double debugLon = 127.06490238136436;

  // 지도 컨트롤러 및 줌
  final MapController mapController = MapController();
  double currentZoom = 17.0;

  // 조이스틱 타이머 및 설정
  Timer? joystickTimer;
  static const double _moveStepMeters = 5.0;
  static const Duration _tickInterval = Duration(milliseconds: 150);

  // RPG 상태 변수
  int coins = 0;
  int level = 1;
  int attackPower = 10;
  double _lastCoinMilestoneDistance = 0.0;

  @override
  void initState() {
    super.initState();
    if (!isDebugMode) {
      _initRealGpsTracking();
    }
  }

  @override
  void dispose() {
    positionStreamSubscription?.cancel();
    joystickTimer?.cancel();
    super.dispose();
  }

  LatLng get currentLatLng {
    if (isDebugMode) {
      return LatLng(debugLat, debugLon);
    } else if (lastPosition != null) {
      return LatLng(lastPosition!.latitude, lastPosition!.longitude);
    }
    return const LatLng(37.5665, 126.9780);
  }

  Future<void> _initRealGpsTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('위치 서비스(GPS)가 꺼져 있습니다.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage('위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage('위치 권한이 영구 거부되었습니다.');
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position newPosition) {
      _onRealPositionUpdate(newPosition);
    });
  }

  void _onRealPositionUpdate(Position newPosition) {
    if (lastPosition != null) {
      final double distanceMoved = calculateHaversineDistance(
        lastPosition!.latitude,
        lastPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      setState(() {
        lastPosition = newPosition;
      });

      _applyMovedDistance(distanceMoved);
      _moveMapToCurrentPosition();
    } else {
      setState(() {
        lastPosition = newPosition;
      });
      _moveMapToCurrentPosition();
    }
  }

  void _startJoystickMove(MoveDirection direction) {
    if (!isDebugMode) return;

    _moveDebugPositionOneStep(direction);

    joystickTimer?.cancel();
    joystickTimer = Timer.periodic(_tickInterval, (timer) {
      _moveDebugPositionOneStep(direction);
    });
  }

  void _stopJoystickMove() {
    joystickTimer?.cancel();
    joystickTimer = null;
  }

  void _moveDebugPositionOneStep(MoveDirection direction) {
    const double metersPerDegreeLat = 111320.0;
    final double metersPerDegreeLon =
        111320.0 * cos(_degreesToRadians(debugLat));

    final double deltaLat = _moveStepMeters / metersPerDegreeLat;
    final double deltaLon = _moveStepMeters / metersPerDegreeLon;

    double newLat = debugLat;
    double newLon = debugLon;

    switch (direction) {
      case MoveDirection.up:
        newLat = debugLat + deltaLat;
        break;
      case MoveDirection.down:
        newLat = debugLat - deltaLat;
        break;
      case MoveDirection.right:
        newLon = debugLon + deltaLon;
        break;
      case MoveDirection.left:
        newLon = debugLon - deltaLon;
        break;
    }

    final double distanceMoved = calculateHaversineDistance(
      debugLat,
      debugLon,
      newLat,
      newLon,
    );

    setState(() {
      debugLat = newLat;
      debugLon = newLon;
    });

    _applyMovedDistance(distanceMoved);
    _moveMapToCurrentPosition();
  }

  void _moveMapToCurrentPosition() {
    mapController.move(currentLatLng, currentZoom);
  }

  void _applyMovedDistance(double distanceMoved) {
    setState(() {
      totalDistance += distanceMoved;

      while (totalDistance - _lastCoinMilestoneDistance >= 100) {
        coins += 10;
        _lastCoinMilestoneDistance += 100;
      }
    });
  }

  int get upgradeCost => level * 30;

  void _upgradeAttackPower() {
    if (coins >= upgradeCost) {
      setState(() {
        coins -= upgradeCost;
        level += 1;
        attackPower += 5;
      });
      _showMessage('강화 성공! Lv.$level / 공격력 $attackPower');
    } else {
      _showMessage('코인이 부족합니다. (필요: $upgradeCost 코인)');
    }
  }

  void _toggleDebugMode(bool newValue) {
    setState(() {
      isDebugMode = newValue;
    });

    if (isDebugMode) {
      positionStreamSubscription?.cancel();
      positionStreamSubscription = null;
      lastPosition = null;
    } else {
      _stopJoystickMove();
      _initRealGpsTracking();
    }

    _moveMapToCurrentPosition();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('러닝 RPG - 지도 & 조이스틱'),
      ),
      body: Column(
        children: [
          // 상단: 스탯 정보 패널
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text(
                  '누적 거리: ${totalDistance.toStringAsFixed(1)} m',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statChip('🪙 코인', '$coins'),
                    _statChip('⭐ Lv', '$level'),
                    _statChip('⚔️ 공격력', '$attackPower'),
                  ],
                ),
              ],
            ),
          ),

          // 중단: 지도 레이어
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: currentLatLng,
                    initialZoom: currentZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.running_rpg_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentLatLng,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // GPS / 시뮬레이터 모드 스위치
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('실제 GPS'),
              Switch(
                value: isDebugMode,
                onChanged: _toggleDebugMode,
              ),
              const Text('가상 시뮬레이터'),
            ],
          ),

          // 하단: 조이스틱 및 강화 버튼
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isDebugMode) _buildJoystick() else _buildGpsWaitingHint(),
                _buildUpgradeButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label $value', style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildGpsWaitingHint() {
    return const SizedBox(
      width: 160,
      child: Text(
        '실제 GPS 모드에서는\n실제 이동 거리가 자동 반영됩니다.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildJoystick() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _joystickButton(Icons.keyboard_arrow_up, MoveDirection.up),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _joystickButton(Icons.keyboard_arrow_left, MoveDirection.left),
              const SizedBox(width: 48),
              _joystickButton(Icons.keyboard_arrow_right, MoveDirection.right),
            ],
          ),
          _joystickButton(Icons.keyboard_arrow_down, MoveDirection.down),
        ],
      ),
    );
  }

  Widget _joystickButton(IconData icon, MoveDirection direction) {
    return GestureDetector(
      onTapDown: (_) => _startJoystickMove(direction),
      onTapUp: (_) => _stopJoystickMove(),
      onTapCancel: () => _stopJoystickMove(),
      child: Container(
        margin: const EdgeInsets.all(4),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.indigo.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 28, color: Colors.indigo.shade900),
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _upgradeAttackPower,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: Text('강화\n(-$upgradeCost 코인)', textAlign: TextAlign.center),
        ),
      ],
    );
  }
}