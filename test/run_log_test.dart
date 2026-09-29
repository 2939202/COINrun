import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contact/models/run_log.dart';
import 'package:contact/models/run_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('저장된 러닝 기록 읽기', () {
    test('숫자들을 읽어온다', () {
      final log = RunLog.fromMap('run1', {
        'distanceMeters': 5000.0,
        'durationSeconds': 1800,
        'goldEarned': 600,
        'expEarned': 300,
      });

      expect(log.id, 'run1');
      expect(log.distanceMeters, 5000.0);
      expect(log.goldEarned, 600);
    });

    // 경로는 routes/{id}에 따로 있습니다. 목록을 읽을 때 딸려오면 안 됩니다.
    test('새 기록은 경로를 들고 있지 않다', () {
      final log = RunLog.fromMap('run1', {'distanceMeters': 5000.0});
      expect(log.legacyRoute.hasPath, isFalse);
    });

    // 경로를 따로 두기 전에 저장된 기록은 기록 문서 안에 경로가 들어 있습니다.
    test('옛 기록은 문서 안의 경로를 그대로 읽는다', () {
      final log = RunLog.fromMap('run1', {
        'distanceMeters': 5000.0,
        'path': const [
          GeoPoint(37.5665, 126.9780),
          GeoPoint(37.5675, 126.9790),
        ],
      });
      expect(log.legacyRoute.hasPath, isTrue);
      expect(log.legacyRoute.points.length, 2);
    });

    test('감춘 기록인지 읽어온다', () {
      expect(RunLog.fromMap('run1', {'hidden': true}).hidden, isTrue);
      // 감추기를 붙이기 전에 저장된 기록에는 이 값이 없습니다. 보이는 것이 맞습니다.
      expect(RunLog.fromMap('run1', {}).hidden, isFalse);
    });

    // 기록을 지울 때 주간/월간 요약에서 같은 만큼 빼야 해서, 이 값들이 필요합니다.
    test('요약에서 빼낼 때 쓰는 값들을 읽어온다', () {
      final log = RunLog.fromMap('run1', {
        'distanceMeters': 5000.0,
        'durationSeconds': 1800,
        'movingSeconds': 1500,
        'steps': 6000,
        'goldEarned': 600,
        'expEarned': 250,
      });
      expect(log.movingSeconds, 1500);
      expect(log.steps, 6000);
      expect(log.expEarned, 250);
    });

    test('값이 빠져 있어도 앱이 죽지 않는다', () {
      final log = RunLog.fromMap('run1', {});
      expect(log.distanceMeters, 0);
      expect(log.createdAt, isNull);
      expect(log.legacyRoute.hasPath, isFalse);
    });
  });

  group('경로 읽기', () {
    test('GeoPoint 목록을 경로로 읽어온다', () {
      final route = RunRoute.fromMap({
        'path': const [
          GeoPoint(37.5665, 126.9780),
          GeoPoint(37.5675, 126.9790),
        ],
      });

      expect(route.segments.length, 1);
      expect(route.points.first.latitude, 37.5665);
      expect(route.points.last.longitude, 126.9790);
      expect(route.hasPath, isTrue);
    });

    // 경로 문서가 아예 없는 경우 (옛 기록이거나 저장에 실패한 경우)
    test('문서가 없으면 빈 경로', () {
      expect(RunRoute.fromMap(null).hasPath, isFalse);
      expect(RunRoute.fromMap({}).hasPath, isFalse);
      expect(RunRoute.empty.hasPath, isFalse);
    });

    test('점이 하나뿐이면 선을 그릴 수 없으므로 경로 없음으로 본다', () {
      final route = RunRoute.fromMap({
        'path': const [GeoPoint(37.5665, 126.9780)],
      });
      expect(route.hasPath, isFalse);
    });

    test('끊긴 구간이 토막으로 나뉘어 읽힌다', () {
      final route = RunRoute.fromMap({
        'path': const [
          GeoPoint(37.5660, 126.9780),
          GeoPoint(37.5661, 126.9780),
          GeoPoint(37.5680, 126.9780), // 여기서 신호가 끊겼다 돌아옴
          GeoPoint(37.5681, 126.9780),
        ],
        'pathBreaks': const [2],
      });

      expect(route.segments.length, 2);
      expect(route.segments[0].length, 2);
      expect(route.segments[1].length, 2);
      expect(route.points.length, 4); // 점 개수는 그대로
    });

    test('저장한 토막을 그대로 다시 읽어온다', () {
      final segments = [
        [const LatLng(37.5660, 126.9780), const LatLng(37.5661, 126.9780)],
        [const LatLng(37.5680, 126.9780), const LatLng(37.5681, 126.9780)],
        [const LatLng(37.5690, 126.9780), const LatLng(37.5691, 126.9780)],
      ];

      final restored = RunRoute.fromMap(RunRoute.toFields(segments));

      expect(restored.segments.length, 3);
      for (int i = 0; i < segments.length; i++) {
        expect(restored.segments[i].length, segments[i].length);
        expect(restored.segments[i].first.latitude, segments[i].first.latitude);
      }
    });

    // 토막을 나누기 전에 저장된 기록에는 pathBreaks가 없습니다.
    test('pathBreaks가 없으면 토막 하나로 본다', () {
      final route = RunRoute.fromMap({
        'path': const [
          GeoPoint(37.5660, 126.9780),
          GeoPoint(37.5661, 126.9780),
          GeoPoint(37.5662, 126.9780),
        ],
      });
      expect(route.segments.length, 1);
      expect(route.segments.first.length, 3);
    });

    test('말이 안 되는 pathBreaks 값이 들어와도 앱이 죽지 않는다', () {
      final route = RunRoute.fromMap({
        'path': const [
          GeoPoint(37.5660, 126.9780),
          GeoPoint(37.5661, 126.9780),
        ],
        'pathBreaks': const [0, -3, 99, 1, 1], // 범위 밖 / 중복 / 맨 앞
      });
      expect(route.segments.length, 2);
      expect(route.points.length, 2);
    });

    test('GeoPoint가 아닌 값이 섞여 있어도 앱이 죽지 않는다', () {
      final route = RunRoute.fromMap({
        'path': ['이상한값', const GeoPoint(37.5665, 126.9780), 42],
      });
      expect(route.points.length, 1);
    });
  });
}
