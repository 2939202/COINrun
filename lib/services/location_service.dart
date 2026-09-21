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

  // 5m 이상 움직일 때마다 새 위치를 알려주는 스트림
  static Stream<Position> positionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
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
