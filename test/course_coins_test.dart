import 'package:contact/game/course_coins.dart';
import 'package:contact/game/official_courses.dart';
import 'package:contact/models/course.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Course _byId(String id) => OfficialCourses.all.firstWhere((c) => c.id == id);

// 코스를 따라 촘촘히 걸어가며 위치를 넣습니다. (실제 GPS처럼 몇 m마다 한 번)
void _walk(CourseCoins coins, List<LatLng> path, {List<CoinUpdate>? log}) {
  for (int i = 1; i < path.length; i++) {
    for (int k = 0; k <= 10; k++) {
      final double t = k / 10;
      final update = coins.update(
        LatLng(
          path[i - 1].latitude + (path[i].latitude - path[i - 1].latitude) * t,
          path[i - 1].longitude +
              (path[i].longitude - path[i - 1].longitude) * t,
        ),
      );
      log?.add(update);
    }
  }
}

void main() {
  group('편도 코스', () {
    final course = _byId('official-danghyeon-full');

    test('코인 30개가 깔리고 편도로 판정된다', () {
      final coins = CourseCoins.forCourse(course);
      expect(coins.coins.length, CourseCoins.count);
      expect(coins.isRoundTrip, isFalse);
      expect(coins.turnPoint, isNull);
    });

    test('코스를 다 지나가면 전부 먹고 1.25배', () {
      final coins = CourseCoins.forCourse(course);
      _walk(coins, course.points);
      expect(coins.allCollected, isTrue);
      expect(coins.gold, (30 * 20 * 1.25).round()); // 750
    });

    test('절반만 가고 그만두면 먹은 만큼만, 배수 없음', () {
      final coins = CourseCoins.forCourse(course);
      _walk(coins, course.points.sublist(0, course.points.length ~/ 2));
      expect(coins.collectedCount, inInclusiveRange(10, 20));
      expect(coins.allCollected, isFalse);
      expect(coins.gold, coins.collectedCount * 20);
    });

    test('코스에서 멀리 있으면 아무것도 못 먹는다', () {
      final coins = CourseCoins.forCourse(course);
      coins.update(const LatLng(37.5665, 126.9780)); // 서울시청
      expect(coins.collectedCount, 0);
    });

    test('같은 코인을 두 번 먹지 않는다', () {
      final coins = CourseCoins.forCourse(course);
      final first = coins.update(coins.coins.first);
      final again = coins.update(coins.coins.first);
      expect(first.collected, 1);
      expect(again.collected, 0);
    });
  });

  group('왕복 코스', () {
    final course = _byId('official-danghyeon-kbu');

    test('왕복으로 판정되고 반환점이 있다', () {
      final coins = CourseCoins.forCourse(course);
      expect(coins.isRoundTrip, isTrue);
      expect(coins.turnPoint, isNotNull);
    });

    test('갈 때는 진동만, 반환점 찍고 돌아오며 다 먹으면 1.5배', () {
      final coins = CourseCoins.forCourse(course);
      final half = course.points.length ~/ 2 + 1;
      final List<CoinUpdate> outbound = [];
      _walk(coins, course.points.sublist(0, half), log: outbound);

      // 가는 길: 지나친 코인마다 한 번씩 진동만. 반환점 바로 옆 코인 한두 개는
      // 반환점을 찍는 순간 먹힐 수 있습니다.
      final int passed = outbound.fold<int>(0, (sum, u) => sum + u.passed);
      expect(coins.collectedCount, lessThanOrEqualTo(2));
      expect(passed + coins.collectedCount, inInclusiveRange(30, 32));
      expect(coins.turned, isTrue);

      _walk(coins, course.points.sublist(half - 1));
      expect(coins.allCollected, isTrue);
      expect(coins.gold, (30 * 20 * 1.5).round()); // 900
    });

    test('반환점 전에 그만두면 0골드', () {
      final coins = CourseCoins.forCourse(course);
      _walk(coins, course.points.sublist(0, 6));
      expect(coins.gold, 0);
    });
  });
}
