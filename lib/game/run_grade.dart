import 'dart:math';

import '../models/run_record.dart';

// ============================================================
// 러닝 등급 (1~5)
//
// 가전제품 에너지 효율 등급처럼 이번 러닝을 한 숫자로 보여줍니다.
//   1 - 가볍게 산책했네
//   5 - 10km 가까이를 꾸준히 빠르게 뛰었네
//
// [어떻게 매기나]
//   거리와 페이스를 같이 봅니다. 거리가 더 중요해서, 아무리 빨라도 짧으면 높게
//   나오지 않고, 오래 걸어도 3을 넘지 않습니다.
//
//   거리 점수  = (km / 10) ^ 0.7          10km에서 1. 짧은 거리도 조금은 쳐줍니다.
//   페이스 점수 = (12 - 분/km) / 7          12분(걷기) 0 ~ 5분(빠른 러닝) 1
//   종합       = 거리 점수 x (0.4 + 0.6 x 페이스 점수)
//
//   10km 6분 페이스 0.91 -> 5     5km 6분 0.56 -> 4     3km 7분 0.33 -> 3
//   10km 걷기 0.40 -> 3           3km 걷기 0.17 -> 1
// ============================================================
class RunGrade {
  RunGrade._();

  static const double fullDistanceKm = 10;
  static const double walkPace = 12; // 분/km
  static const double fastPace = 5;

  // 종합 점수가 이 이상이면 그 등급 (5, 4, 3, 2 순서)
  static const List<double> thresholds = [0.8, 0.55, 0.33, 0.2];

  static const List<String> verdicts = [
    '가벼운 산책',
    '걷고 뛰기',
    '괜찮은 러닝',
    '열심히 달렸어요',
    '최고의 러닝',
  ];

  static double score(RunRecord run) {
    final double km = run.distanceMeters / 1000;
    if (km <= 0) return 0;
    final double distance = pow(
      (km / fullDistanceKm).clamp(0.0, 1.0),
      0.7,
    ).toDouble();
    return distance * (0.4 + 0.6 * paceScore(run));
  }

  // 0(걷기) ~ 1(빠른 러닝). 거리가 너무 짧으면 페이스를 믿을 수 없어서 0입니다.
  static double paceScore(RunRecord run) {
    final double? pace = movingPace(run);
    if (pace == null) return 0;
    return ((walkPace - pace) / (walkPace - fastPace)).clamp(0.0, 1.0);
  }

  // 움직인 시간 기준 페이스 (분/km). 신호 대기처럼 서 있던 시간은 빼고 봅니다.
  static double? movingPace(RunRecord run) {
    final double km = run.distanceMeters / 1000;
    if (km < 0.2 || run.movingTime.inSeconds <= 0) return null;
    return run.movingTime.inSeconds / 60 / km;
  }

  static int of(RunRecord run) {
    final double s = score(run);
    for (int i = 0; i < thresholds.length; i++) {
      if (s >= thresholds[i]) return 5 - i;
    }
    return 1;
  }

  static String verdict(int grade) => verdicts[grade.clamp(1, 5) - 1];
}
