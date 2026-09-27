import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contact/models/run_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('저장된 러닝 기록 읽기', () {
    test('GeoPoint 목록을 경로로 읽어온다', () {
      final log = RunLog.fromMap({
        'distanceMeters': 5000.0,
        'durationSeconds': 1800,
        'goldEarned': 600,
        'expEarned': 300,
        'path': [
          const GeoPoint(37.5665, 126.9780),
          const GeoPoint(37.5675, 126.9790),
        ],
      });

      expect(log.path.length, 2);
      expect(log.path.first.latitude, 37.5665);
      expect(log.path.last.longitude, 126.9790);
      expect(log.hasPath, isTrue);
    });

    // 경로 저장을 붙이기 전에 뛴 기록에는 path 필드가 아예 없습니다.
    test('경로가 없는 옛 기록도 읽히고, 지도를 그리지 않는다고 알려준다', () {
      final log = RunLog.fromMap({'distanceMeters': 3000.0});
      expect(log.path, isEmpty);
      expect(log.hasPath, isFalse);
    });

    test('점이 하나뿐이면 선을 그릴 수 없으므로 경로 없음으로 본다', () {
      final log = RunLog.fromMap({
        'path': [const GeoPoint(37.5665, 126.9780)],
      });
      expect(log.hasPath, isFalse);
    });

    test('GeoPoint가 아닌 값이 섞여 있어도 앱이 죽지 않는다', () {
      final log = RunLog.fromMap({
        'path': ['이상한값', const GeoPoint(37.5665, 126.9780), 42],
      });
      expect(log.path.length, 1);
    });
  });
}
