import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

  // 마지막으로 알고 있던 위치. 기다리지 않고 바로 돌아옵니다.
  //
  // 러닝 화면에 들어오자마자 지도에 내 위치를 찍어두는 용도입니다.
  // 스트림만으로는 5m를 움직이기 전까지 아무것도 안 들어와서, 화면을 열어도
  // 내 위치를 모르는 상태가 계속됩니다.
  //
  // getCurrentPosition이 아니라 getLastKnownPosition을 쓰는 이유:
  // 전자는 새 측위를 요청해서 최대 몇 초 걸리고 스트림과 같은 자원을 잡습니다.
  // 후자는 폰이 이미 들고 있는 값을 그대로 돌려줘서 즉시 끝나고 부딪히지 않습니다.
  static Future<Position?> lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
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
    // 포그라운드 서비스는 안드로이드에만 있는 개념입니다.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        // distanceFilter를 0으로 둬서 움직이지 않아도 2초마다 위치를 받습니다.
        //
        // 5m로 두면 가만히 있을 때 아무것도 안 들어오는데, 그 모습이 "스트림이 죽은 것"과
        // 화면에서 똑같이 보입니다. 실제로 이것 때문에 고장인 줄 알고 한참 헤맸습니다.
        // 제자리 흔들림으로 거리가 부풀지 않게 거르는 일은 RunTracker가 합니다.
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 2),
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

    return const LocationSettings(accuracy: LocationAccuracy.high);
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
