import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// GPS 권한 요청과 위치 수신
// ============================================================
class LocationService {
  LocationService._();

  // 오차가 이보다 큰 위치는 버립니다.
  // (가만히 있어도 GPS가 흔들려서 거리가 쌓이는 것을 막기 위함)
  static const double maxAccuracyMeters = 25;

  // 권한이 확보되면 null, 아니면 사용자에게 보여줄 안내 문구를 돌려줍니다.
  static Future<String?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return '위치 서비스(GPS)가 꺼져 있습니다. 설정에서 켜주세요.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return '위치 권한이 거부되었습니다.';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return '위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 권한을 허용해주세요.';
    }
    return null;
  }

  // 안드로이드 13부터 알림을 보여주려면 따로 받아야 합니다.
  // 거부해도 위치는 계속 받습니다. 알림만 안 보입니다.
  static Future<void> requestNotificationPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await Permission.notification.request();
  }

  // 지금 위치 한 번만. (러닝 시작 전에 지도에 내 위치를 찍어두는 용도)
  //
  // 시작 전에 스트림을 열지 않는 이유가 있습니다. geolocator는 이미 열린 스트림이 있으면
  // 새로 요청해도 그걸 그대로 돌려주고 새 설정을 무시합니다(geolocator_android.dart:167).
  // 그래서 시작 전에 스트림을 열어두면, 러닝을 시작할 때 포그라운드 설정을 넣어 다시
  // 열어도 먹지 않을 수 있습니다. 스트림은 러닝을 시작할 때 딱 한 번만 엽니다.
  static Future<Position?> currentPosition() async {
    try {
      // 마지막으로 알던 위치가 있으면 기다리지 않고 바로 씁니다.
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      // 실내처럼 신호를 못 잡는 곳이면 그냥 못 받은 채로 둡니다. 지도는 기본 위치를 보여줍니다.
      return null;
    }
  }

  // 5m 이상 움직일 때마다 새 위치를 알려주는 스트림
  //
  // keepAliveInBackground를 켜면 알림창에 "달리는 중" 알림을 띄우는
  // 포그라운드 서비스가 함께 돌아갑니다. 이게 없으면 안드로이드 8부터는
  // 다른 앱으로 넘어가거나 화면을 끄는 순간 위치 전달이 끊깁니다.
  //
  // 러닝을 시작할 때만 켭니다. 시작 전 지도에 내 위치만 찍어두는 동안에도
  // 알림이 떠 있으면 이상하기 때문입니다.
  static Stream<Position> positionStream({bool keepAliveInBackground = false}) {
    return Geolocator.getPositionStream(
      locationSettings: _settings(keepAliveInBackground),
    );
  }

  static LocationSettings _settings(bool keepAliveInBackground) {
    const double accuracyFilterMeters = 5;

    // 포그라운드 서비스는 안드로이드에만 있는 개념입니다.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: accuracyFilterMeters.toInt(),
        foregroundNotificationConfig: keepAliveInBackground
            ? const ForegroundNotificationConfig(
                notificationTitle: '달리는 중',
                notificationText: '거리와 경로를 기록하고 있어요.',
                notificationChannelName: '러닝 기록',
                // 화면이 꺼져도 위치가 계속 들어오게 합니다.
                // 이게 없으면 폰이 잠든 동안 위치가 쌓였다가 깨어날 때 한꺼번에 들어옵니다.
                enableWakeLock: true,
                // 사용자가 알림을 지워서 기록이 끊기는 일을 막습니다.
                setOngoing: true,
              )
            : null,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  // 두 좌표 사이 거리(m)
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
