import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contact/models/run_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

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

      expect(log.segments.length, 1);
      expect(log.segments.first.length, 2);
      expect(log.path.first.latitude, 37.5665);
      expect(log.path.last.longitude, 126.9790);
      expect(log.hasPath, isTrue);
    });

    // 경로 저장을 붙이기 전에 뛴 기록에는 path 필드가 아예 없습니다.
    test('경로가 없는 옛 기록도 읽히고, 지도를 그리지 않는다고 알려준다', () {
      final log = RunLog.fromMap({'distanceMeters': 3000.0});
      expect(log.segments, isEmpty);
      expect(log.hasPath, isFalse);
    });

    test('점이 하나뿐이면 선을 그릴 수 없으므로 경로 없음으로 본다', () {
      final log = RunLog.fromMap({
        'path': [const GeoPoint(37.5665, 126.9780)],
      });
      expect(log.hasPath, isFalse);
    });

    test('끊긴 구간이 토막으로 나뉘어 읽힌다', () {
      final log = RunLog.fromMap({
        'path': const [
          GeoPoint(37.5660, 126.9780),
          GeoPoint(37.5661, 126.9780),
          GeoPoint(37.5680, 126.9780), // 여기서 신호가 끊겼다 돌아옴
          GeoPoint(37.5681, 126.9780),
        ],
        'pathBreaks': const [2],
      });

      expect(log.segments.length, 2);
      expect(log.segments[0].length, 2);
      expect(log.segments[1].length, 2);
      expect(log.path.length, 4); // 점 개수는 그대로
    });

    test('저장한 토막을 그대로 다시 읽어온다', () {
      final segments = [
        [const LatLng(37.5660, 126.9780), const LatLng(37.5661, 126.9780)],
        [const LatLng(37.5680, 126.9780), const LatLng(37.5681, 126.9780)],
        [const LatLng(37.5690, 126.9780), const LatLng(37.5691, 126.9780)],
      ];

      final restored = RunLog.fromMap(RunLog.pathFields(segments));

      expect(restored.segments.length, 3);
      for (int i = 0; i < segments.length; i++) {
        expect(restored.segments[i].length, segments[i].length);
        expect(restored.segments[i].first.latitude, segments[i].first.latitude);
      }
    });

    // 토막을 나누기 전에 저장된 기록에는 pathBreaks가 없습니다.
    test('pathBreaks가 없으면 토막 하나로 본다', () {
      final log = RunLog.fromMap({
        'path': const [
          GeoPoint(37.5660, 126.9780),
          GeoPoint(37.5661, 126.9780),
          GeoPoint(37.5662, 126.9780),
        ],
      });
      expect(log.segments.length, 1);
      expect(log.segments.first.length, 3);
    });

    test('말이 안 되는 pathBreaks 값이 들어와도 앱이 죽지 않는다', () {
      final log = RunLog.fromMap({
        'path': const [
          GeoPoint(37.5660, 126.9780),
          GeoPoint(37.5661, 126.9780),
        ],
        'pathBreaks': const [0, -3, 99, 1, 1], // 범위 밖 / 중복 / 맨 앞
      });
      expect(log.segments.length, 2);
      expect(log.path.length, 2);
    });

    test('GeoPoint가 아닌 값이 섞여 있어도 앱이 죽지 않는다', () {
      final log = RunLog.fromMap({
        'path': ['이상한값', const GeoPoint(37.5665, 126.9780), 42],
      });
      expect(log.path.length, 1);
    });
  });
}
