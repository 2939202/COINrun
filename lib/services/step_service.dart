import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// 폰 걸음 센서
//   - 안드로이드: 활동 인식(ACTIVITY_RECOGNITION) 권한을 직접 요청해야 합니다.
//   - iOS: 센서를 처음 읽을 때 시스템이 알아서 "동작 및 피트니스" 권한을 물어봅니다.
//   - 웹/PC: 걸음 센서가 없으므로 사용하지 않습니다. (RunTracker가 거리로 추정)
// ============================================================
class StepService {
  StepService._();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // 권한이 이미 있는지만 확인합니다. (요청하지 않음)
  //
  // 요청은 services/app_permissions.dart가 순서대로 처리합니다.
  // 여기저기서 따로 요청하면 권한 창이 겹쳐서 하나가 씹힙니다.
  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Permission.activityRecognition.isGranted;
    }
    return true;
  }

  // 걸음 센서 권한을 요청합니다. AppPermissions에서만 부릅니다.
  static Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return (await Permission.activityRecognition.request()).isGranted;
    }
    return true;
  }

  // 폰을 켠 뒤 누적 걸음 수 (걸을 때마다 새 값이 들어옴)
  static Stream<int> stepCountStream() =>
      Pedometer.stepCountStream.map((event) => event.steps);
}
