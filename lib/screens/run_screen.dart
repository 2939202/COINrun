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
  const double earthRadius = 6371000;

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

enum MoveDirection { up, down, left, right }

class AvatarSkin {
  final String id;
  final String emoji;
  final String name;
  final int price;

  const AvatarSkin({
    required this.id,
    required this.emoji,
    required this.name,
    required this.price,
  });
}

const List<AvatarSkin> avatarShopItems = [
  AvatarSkin(id: 'basic', emoji: '🔴', name: '기본 러너', price: 0),
  AvatarSkin(id: 'blue_speeder', emoji: '🔵', name: '파랑 스피더', price: 50),
  AvatarSkin(id: 'gold_wind', emoji: '🟡', name: '골드 윈드', price: 100),
  AvatarSkin(id: 'lion_champion', emoji: '🦁', name: '사자 챔피언', price: 200),
];

// ------------------------------------------------------------
// RunScreen: 지도 + GPS + 조이스틱 + 랭킹 & 아바타 통합 화면
// ------------------------------------------------------------
class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  bool isDebugMode = true;
  double totalDistance = 0.0;
  Position? lastPosition;
  StreamSubscription<Position>? positionStreamSubscription;
  double debugLat = 37.5665;
  double debugLon = 126.9780;

  final MapController mapController = MapController();
  double currentZoom = 17.0;
  Timer? joystickTimer;
  static const double _moveStepMeters = 5.0;
  static const Duration _tickInterval = Duration(milliseconds: 150);

  List<LatLng> pathCoordinates = [];

  int coins = 0;
  int exp = 0;
  int level = 1;
  String userRank = '브론즈 러너';
  double _lastRewardMilestoneDistance = 0.0;

  String currentSkin = 'basic';
  Set<String> unlockedSkins = {'basic'};

  @override
  void initState() {
    super.initState();
    userRank = _calculateRank(level);
    pathCoordinates.add(currentLatLng);

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

  AvatarSkin get currentSkinData {
    return avatarShopItems.firstWhere(
          (skin) => skin.id == currentSkin,
      orElse: () => avatarShopItems.first,
    );
  }

  int get expNeededForNextLevel => level * 100;

  String _calculateRank(int lv) {
    if (lv >= 10) return '다이아 러너';
    if (lv >= 7) return '플래티넘 러너';
    if (lv >= 5) return '골드 러너';
    if (lv >= 3) return '실버 러너';
    return '브론즈 러너';
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
        pathCoordinates.add(
          LatLng(newPosition.latitude, newPosition.longitude),
        );
      });

      _applyMovedDistance(distanceMoved);
      _moveMapToCurrentPosition();
    } else {
      setState(() {
        lastPosition = newPosition;
        pathCoordinates.add(
          LatLng(newPosition.latitude, newPosition.longitude),
        );
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
      pathCoordinates.add(LatLng(newLat, newLon));
    });

    _applyMovedDistance(distanceMoved);
    _moveMapToCurrentPosition();
  }

  void _moveMapToCurrentPosition() {
    mapController.move(currentLatLng, currentZoom);
  }

  void _applyMovedDistance(double distanceMoved) {
    bool leveledUp = false;

    setState(() {
      totalDistance += distanceMoved;

      while (totalDistance - _lastRewardMilestoneDistance >= 100) {
        coins += 10;
        exp += 50;
        _lastRewardMilestoneDistance += 100;

        while (exp >= expNeededForNextLevel) {
          exp -= expNeededForNextLevel;
          level += 1;
          userRank = _calculateRank(level);
          leveledUp = true;
        }
      }
    });

    if (leveledUp) {
      _showMessage('🎉 레벨업! Lv.$level ($userRank)');
    }
  }

  void _buyOrEquipSkin(AvatarSkin skin, StateSetter setModalState) {
    final bool alreadyOwned = unlockedSkins.contains(skin.id);

    if (alreadyOwned) {
      setState(() {
        currentSkin = skin.id;
      });
      _showMessage('${skin.emoji} ${skin.name} 착용!');
    } else {
      if (coins >= skin.price) {
        setState(() {
          coins -= skin.price;
          unlockedSkins.add(skin.id);
          currentSkin = skin.id;
        });
        _showMessage('${skin.emoji} ${skin.name} 구매 완료!');
      } else {
        _showMessage('코인이 부족합니다. (필요: ${skin.price}코인)');
        return;
      }
    }

    setModalState(() {});
  }

  void _openAvatarShop() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🛍️ 아바타 스킨 상점',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('보유 코인: 🪙 $coins'),
                  const SizedBox(height: 12),
                  ...avatarShopItems.map((skin) {
                    final bool owned = unlockedSkins.contains(skin.id);
                    final bool equipped = currentSkin == skin.id;

                    String buttonLabel;
                    if (equipped) {
                      buttonLabel = '착용중';
                    } else if (owned) {
                      buttonLabel = '착용하기';
                    } else {
                      buttonLabel = '구매 (${skin.price}코인)';
                    }

                    return ListTile(
                      leading: Text(
                        skin.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(skin.name),
                      subtitle: Text(
                        skin.price == 0 ? '기본 제공 스킨' : '${skin.price} 코인',
                      ),
                      trailing: ElevatedButton(
                        onPressed: equipped
                            ? null
                            : () => _buyOrEquipSkin(skin, setModalState),
                        child: Text(buttonLabel),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
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
        title: const Text('러닝 RPG - 랭킹 & 아바타'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text(
                  '누적 거리: ${totalDistance.toStringAsFixed(1)} m',
                  style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statChip('🪙 코인', '$coins'),
                    _statChip('⭐ Lv', '$level'),
                    _statChip('🏅 랭킹', userRank),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: exp / expNeededForNextLevel,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EXP $exp / $expNeededForNextLevel',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: pathCoordinates,
                          strokeWidth: 5.0,
                          color: Colors.indigoAccent,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentLatLng,
                          width: 44,
                          height: 44,
                          child: Text(
                            currentSkinData.emoji,
                            style: const TextStyle(fontSize: 32),
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
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isDebugMode) _buildJoystick() else _buildGpsWaitingHint(),
                _buildShopEntryButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label $value', style: const TextStyle(fontSize: 13)),
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

  Widget _buildShopEntryButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(currentSkinData.emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _openAvatarShop,
          icon: const Icon(Icons.storefront),
          label: const Text('아바타 상점'),
        ),
      ],
    );
  }
}