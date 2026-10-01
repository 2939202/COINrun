import 'package:latlong2/latlong.dart';

import '../models/course.dart';

// ============================================================
// 코스 러닝의 코인
//
// 코스 러닝에서는 걸음 수로 골드를 주지 않습니다. 대신 코스 위에 코인을 깔아두고
// 지나가며 먹은 만큼만 줍니다. 그래야 골드가 두 번 쌓이지 않습니다.
//
// [규칙]
//   - 코인 30개를 코스 위에 같은 간격으로 깝니다.
//   - 25m 안으로 지나가면 먹은 것으로 칩니다. GPS가 10~20m씩 흔들려서 넉넉하게 잡습니다.
//   - 중간에 그만둬도 먹은 코인만큼은 받습니다.
//   - 다 먹으면 코인 골드 전체에 편도 1.25배, 왕복 1.5배를 곱해 줍니다.
//
// [왕복 코스]
//   갈 때와 올 때 같은 길을 지나서 코인이 겹칩니다. 그래서 코인은 한 벌만 깔고,
//   갈 때 지나가면 진동만 울리고(아직 못 먹음) 반환점을 찍은 뒤 돌아오는 길에 먹습니다.
// ============================================================
class CourseCoins {
  static const int count = 30;
  static const int goldPerCoin = 20;
  static const double pickupRadiusMeters = 25;

  // 반환점은 코인보다 조금 더 넉넉하게 봅니다. 여기서 놓치면 하나도 못 먹게 됩니다.
  static const double turnRadiusMeters = 40;

  // 출발과 도착이 이만큼 가까우면 왕복 코스로 봅니다.
  static const double roundTripGapMeters = 50;

  static const double oneWayBonus = 1.25;
  static const double roundTripBonus = 1.5;

  static const Distance _distance = Distance();

  final bool isRoundTrip;
  final List<LatLng> coins;
  final LatLng? turnPoint; // 왕복 코스의 반환점

  final Set<int> _collected = {};
  final Set<int> _buzzed = {}; // 왕복에서 갈 때 이미 진동을 울린 코인
  bool _turned = false;

  CourseCoins._({
    required this.isRoundTrip,
    required this.coins,
    required this.turnPoint,
  });

  factory CourseCoins.forCourse(Course course) {
    final List<LatLng> path = course.points;
    final bool roundTrip =
        path.length >= 2 &&
        _distance(path.first, path.last) <= roundTripGapMeters;
    final double total = _length(path);

    // 왕복이면 가는 길(앞 절반)에만 깔면 됩니다. 돌아오는 길도 같은 자리를 지나갑니다.
    final double span = roundTrip ? total / 2 : total;
    return CourseCoins._(
      isRoundTrip: roundTrip,
      coins: [
        for (int i = 0; i < count; i++)
          _pointAt(path, span * (i + 0.5) / count),
      ],
      turnPoint: roundTrip ? _pointAt(path, total / 2) : null,
    );
  }

  int get collectedCount => _collected.length;
  bool get allCollected => _collected.length == coins.length;
  bool get turned => _turned;
  bool isCollected(int index) => _collected.contains(index);

  // 다 먹었을 때 곱하는 배수
  double get completionBonus => isRoundTrip ? roundTripBonus : oneWayBonus;

  // 장비 보너스를 붙이기 전의 골드
  int get gold {
    final int base = _collected.length * goldPerCoin;
    return allCollected ? (base * completionBonus).round() : base;
  }

  // 새 위치가 들어올 때마다 부릅니다. 무슨 일이 있었는지 돌려줍니다.
  CoinUpdate update(LatLng position) {
    final LatLng? turn = turnPoint;
    bool justTurned = false;
    if (turn != null &&
        !_turned &&
        _distance(position, turn) <= turnRadiusMeters) {
      _turned = true;
      justTurned = true;
    }

    // 왕복인데 아직 반환점을 안 찍었으면 먹지 않고 진동만 울립니다.
    final bool canCollect = !isRoundTrip || _turned;

    int collected = 0;
    int passed = 0;
    for (int i = 0; i < coins.length; i++) {
      if (_collected.contains(i)) continue;
      if (_distance(position, coins[i]) > pickupRadiusMeters) continue;
      if (canCollect) {
        _collected.add(i);
        collected += 1;
      } else if (_buzzed.add(i)) {
        passed += 1;
      }
    }
    return CoinUpdate(collected: collected, passed: passed, turned: justTurned);
  }

  static double _length(List<LatLng> path) {
    double total = 0;
    for (int i = 1; i < path.length; i++) {
      total += _distance(path[i - 1], path[i]);
    }
    return total;
  }

  // 출발점에서 길을 따라 meters만큼 간 자리
  static LatLng _pointAt(List<LatLng> path, double meters) {
    double walked = 0;
    for (int i = 1; i < path.length; i++) {
      final double piece = _distance(path[i - 1], path[i]);
      if (walked + piece >= meters && piece > 0) {
        final double t = (meters - walked) / piece;
        return LatLng(
          path[i - 1].latitude + (path[i].latitude - path[i - 1].latitude) * t,
          path[i - 1].longitude +
              (path[i].longitude - path[i - 1].longitude) * t,
        );
      }
      walked += piece;
    }
    return path.last;
  }
}

// 코스 러닝을 마쳤을 때 저장할 것
class CourseResult {
  final String courseId;
  final int coinsCollected;
  final int coinsTotal;
  final int gold; // 장비 보너스 전

  const CourseResult({
    required this.courseId,
    required this.coinsCollected,
    required this.coinsTotal,
    required this.gold,
  });

  factory CourseResult.of(String courseId, CourseCoins coins) => CourseResult(
    courseId: courseId,
    coinsCollected: coins.collectedCount,
    coinsTotal: coins.coins.length,
    gold: coins.gold,
  );

  bool get completed => coinsCollected >= coinsTotal;
}

// 위치 하나가 들어왔을 때 생긴 일
class CoinUpdate {
  final int collected; // 이번에 먹은 코인 수
  final int passed; // 왕복에서 갈 때 지나친 코인 수 (진동만)
  final bool turned; // 이번에 반환점을 찍었는지

  const CoinUpdate({
    required this.collected,
    required this.passed,
    required this.turned,
  });

  bool get isEmpty => collected == 0 && passed == 0 && !turned;
}
