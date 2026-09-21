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

  // 걸음 센서를 쓸 수 있으면 true
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
