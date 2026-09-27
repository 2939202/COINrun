import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'step_service.dart';

// ============================================================
// 앱이 쓰는 권한을 한곳에서 요청합니다.
//
// [반드시 하나씩 순서대로 물어봐야 합니다]
//   안드로이드는 권한 창을 한 번에 하나만 띄웁니다. 두 개를 동시에 요청하면
//   뒤엣것이 조용히 씹혀서 거부된 것으로 처리됩니다. 예전에는 러닝 화면에서
//   위치와 걸음 센서를 동시에 요청해서, 허용을 눌러도 안 먹거나 나중에 엉뚱한
//   때 다시 뜨는 일이 있었습니다.
//
//   그래서 이 파일의 request()는 await로 하나씩 끝내고 다음으로 넘어갑니다.
//   권한을 요청하는 코드는 전부 여기를 거치게 해서, 다시는 겹치지 않게 합니다.
// ============================================================
class AppPermissions {
  AppPermissions._();

  static Future<AppPermissionStatus> check() async {
    return AppPermissionStatus(
      location: await _hasLocation(),
      activity: await _hasActivity(),
      notification: await _hasNotification(),
    );
  }

  // 하나씩 순서대로 물어봅니다. 중간에 거부해도 멈추지 않고 다음 것을 물어봅니다.
  static Future<AppPermissionStatus> request() async {
    // 1. 위치 - 없으면 거리도 경로도 기록되지 않습니다. 가장 중요합니다.
    if (!await _hasLocation()) {
      await Geolocator.requestPermission();
    }

    // 2. 신체 활동 - 없으면 걸음 수를 거리로 어림잡습니다. 골드가 실제보다 적게 나옵니다.
    if (!await _hasActivity()) {
      await StepService.ensurePermission();
    }

    // 3. 알림 - 없어도 기록은 됩니다. 화면을 껐을 때 "달리는 중" 알림만 안 보입니다.
    if (!await _hasNotification()) {
      await Permission.notification.request();
    }

    return check();
  }

  // 권한을 "다시 묻지 않음"으로 거부했으면 앱에서는 더 물어볼 수 없습니다.
  // 이때는 시스템 설정 화면을 열어주는 수밖에 없습니다.
  static Future<bool> locationDeniedForever() async {
    return await Geolocator.checkPermission() ==
        LocationPermission.deniedForever;
  }

  static Future<void> openSettings() => openAppSettings();

  static Future<bool> _hasLocation() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<bool> _hasActivity() async {
    if (!StepService.isSupported) return true; // 센서가 없는 기기는 물어볼 것이 없습니다.
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return Permission.activityRecognition.isGranted;
  }

  static Future<bool> _hasNotification() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    return Permission.notification.isGranted;
  }
}

class AppPermissionStatus {
  final bool location;
  final bool activity;
  final bool notification;

  const AppPermissionStatus({
    required this.location,
    required this.activity,
    required this.notification,
  });

  // 위치가 없으면 러닝 자체가 기록되지 않습니다. 나머지는 없어도 돌아갑니다.
  bool get canRecord => location;

  bool get allGranted => location && activity && notification;
}
