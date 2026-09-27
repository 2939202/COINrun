import 'package:latlong2/latlong.dart';

// 러닝 한 번의 기록과, 그걸로 계산하는 페이스/칼로리
class RunRecord {
  final Duration elapsed; // 시작~완료 전체 시간 (일시정지 제외)
  final Duration movingTime; // 실제로 움직인 시간 -> 경험치 기준
  final double distanceMeters;
  final int steps; // 걸음 수 -> 골드 기준
  final bool stepsEstimated; // 걸음 센서가 없어 거리로 추정한 값인지
  final List<LatLng> path; // 지나온 길. 완료 리포트와 기록 상세의 지도에 그립니다.

  const RunRecord({
    required this.elapsed,
    required this.movingTime,
    required this.distanceMeters,
    required this.steps,
    required this.stepsEstimated,
    this.path = const [],
  });

  double get distanceKm => distanceMeters / 1000;

  // 평균 페이스: 1km를 달리는 데 걸린 시간(분). 거리가 거의 없으면 계산하지 않습니다.
  double? get paceMinPerKm {
    if (distanceKm < 0.01) return null;
    return elapsed.inSeconds / 60.0 / distanceKm;
  }

  // 추정 소모 칼로리 - 1km당 약 60kcal로 단순 계산
  double get calories => distanceKm * 60;
}
