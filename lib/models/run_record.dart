// 러닝 한 번의 기록 (시간 + 거리)과, 그걸로 계산하는 페이스/칼로리
class RunRecord {
  final Duration elapsed;
  final double distanceMeters;

  const RunRecord({required this.elapsed, required this.distanceMeters});

  double get distanceKm => distanceMeters / 1000;

  // 평균 페이스: 1km를 달리는 데 걸린 시간(분). 거리가 거의 없으면 계산하지 않습니다.
  double? get paceMinPerKm {
    if (distanceKm < 0.01) return null;
    return elapsed.inSeconds / 60.0 / distanceKm;
  }

  // 추정 소모 칼로리 - 1km당 약 60kcal로 단순 계산
  double get calories => distanceKm * 60;
}
