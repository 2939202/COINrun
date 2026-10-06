import 'dart:math';

import '../models/run_log.dart';

// ============================================================
// 훈련 부하 모델 - AI 분석의 숫자는 전부 여기서 나옵니다.
//
// LLM(Gemini)에게 숫자를 계산시키지 않습니다. 같은 기록이면 언제나 같은 값이 나와야
// 하고(재현성), 틀리면 다칠 수 있기 때문입니다. LLM은 여기서 나온 값을 설명만 합니다.
//
// 사용자가 따로 입력하는 것은 없습니다. 이미 쌓이는 거리, 움직인 시간, 걸음 수만 씁니다.
//
// [1] 역치 페이스 추정
//   역치 페이스 = 1시간 정도 버틸 수 있는 가장 빠른 페이스. 강도의 기준이 됩니다.
//   각 러닝을 Riegel 공식 T2 = T1 x (D2/D1)^1.06 으로 10km 기록으로 바꾸고,
//   가장 좋은 10km 환산 페이스에 1.04를 곱해 역치로 봅니다.
//   (훈련 기록이라 경기 기록보다 느리므로, 실제보다 보수적인 쪽으로 나옵니다)
//   기록이 적으면 입문자 기본값(7분/km) 쪽으로 당겨서 봅니다. (축소 추정)
//
// [2] 러닝 한 번의 부하 (rTSS 방식)
//   강도 IF = 역치 페이스 / 이번 페이스  (역치로 달리면 1.0)
//   부하   = 움직인 시간(시) x IF^2 x 100   (역치로 1시간 = 100)
//   케이던스(분당 걸음)가 140 미만이면 걷기로 보고 강도를 0.6 이하로 묶습니다.
//
// [3] 체력 / 피로 / 컨디션 (Banister 체력-피로 모델)
//   체력 = 하루 부하의 42일 지수가중평균,  피로 = 7일 지수가중평균
//   컨디션 = 체력 - 피로.  음수가 크면 피로가 쌓인 상태입니다.
//
// [4] 급성:만성 부하 비율 (ACWR, 지수가중평균 방식)
//   최근 7일 부하 / 최근 28일 부하.  1.3을 넘으면 갑자기 많이 늘린 것으로 봅니다.
//   이 지표의 부상 예측력에는 논쟁이 있습니다. 그래서 예측에 쓰지 않고
//   "목표를 더 올리지 않는 안전장치"로만 씁니다. (goal_policy.dart)
// ============================================================

// 분석에 쓰는 러닝 한 번
class Session {
  final DateTime day; // 날짜만
  final double km;
  final int movingSeconds;
  final int steps;
  final bool stepsEstimated;

  const Session({
    required this.day,
    required this.km,
    required this.movingSeconds,
    required this.steps,
    this.stepsEstimated = false,
  });

  static Session? fromLog(RunLog log) {
    final DateTime? at = log.createdAt?.toLocal();
    if (at == null) return null;
    return Session(
      day: DateTime(at.year, at.month, at.day),
      km: log.distanceMeters / 1000,
      movingSeconds: log.movingSeconds,
      steps: log.steps,
      stepsEstimated: log.stepsEstimated,
    );
  }

  // 페이스를 믿을 만큼 움직였는지
  bool get usable => km >= 0.2 && movingSeconds >= 60;

  double get pace => movingSeconds / 60 / km; // 분/km

  // 분당 걸음. 추정 걸음이면 없음
  double? get cadence =>
      stepsEstimated || steps <= 0 ? null : steps / (movingSeconds / 60);

  // 걷기인지. 케이던스가 있으면 그걸로, 없으면 페이스(9.5분/km보다 느림)로 봅니다.
  bool get isWalk {
    final double? c = cadence;
    return c != null ? c < TrainingModel.walkCadence : pace > 9.5;
  }
}

class TrainingModel {
  TrainingModel._();

  static const double riegelExponent = 1.06;
  static const double thresholdFactor = 1.04; // 10km 환산 페이스 -> 역치 페이스
  static const double defaultThresholdPace = 7.0; // 기록이 없을 때 (분/km)
  static const double priorWeight = 3; // 기본값을 러닝 3번만큼으로 칩니다
  static const double walkCadence = 140;
  static const double walkMaxIntensity = 0.6;

  static const int fitnessDays = 42;
  static const int fatigueDays = 7;
  static const int acuteDays = 7;
  static const int chronicDays = 28;

  // 역치 추정에 쓸 기록: 최근 90일, 1.5km 이상, 걷기 아님
  static const int thresholdLookbackDays = 90;
  static const double thresholdMinKm = 1.5;

  static TrainingState analyze(List<Session> sessions, DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<Session> runs = sessions.where((s) => s.usable).toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    // [1] 역치 페이스
    final List<Session> candidates = runs
        .where(
          (s) =>
              !s.isWalk &&
              s.km >= thresholdMinKm &&
              today.difference(s.day).inDays <= thresholdLookbackDays,
        )
        .toList();
    double? bestTenK; // 초
    Session? bestRun;
    for (final s in candidates) {
      final double t10 = riegel(s.movingSeconds.toDouble(), s.km, 10);
      if (bestTenK == null || t10 < bestTenK) {
        bestTenK = t10;
        bestRun = s;
      }
    }
    final double measured = bestTenK == null
        ? defaultThresholdPace
        : bestTenK / 60 / 10 * thresholdFactor;
    final double n = candidates.length.toDouble();
    final double thresholdPace =
        (n * measured + priorWeight * defaultThresholdPace) / (n + priorWeight);

    // [2] 하루 부하
    final Map<DateTime, double> loadByDay = {};
    for (final s in runs) {
      loadByDay[s.day] = (loadByDay[s.day] ?? 0) + loadOf(s, thresholdPace);
    }

    // [3][4] 첫 기록 날부터 오늘까지 하루씩 굴립니다.
    //
    // 0에서 시작하면 기록이 몇 주뿐일 때 평균이 덜 쌓여서 비율이 크게 틀어집니다.
    // 그래서 그 기간의 하루 평균 부하에서 시작합니다. (지수가중평균의 초기값 보정)
    double fitness = 0, fatigue = 0, acute = 0, chronic = 0;
    if (runs.isNotEmpty) {
      final int spanDays = today.difference(runs.first.day).inDays + 1;
      final double meanDaily =
          loadByDay.values.fold<double>(0, (a, b) => a + b) / spanDays;
      fitness = fatigue = acute = chronic = meanDaily;
      for (
        DateTime d = runs.first.day;
        !d.isAfter(today);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        final double load = loadByDay[d] ?? 0;
        fitness += (load - fitness) / fitnessDays;
        fatigue += (load - fatigue) / fatigueDays;
        acute += (load - acute) * 2 / (acuteDays + 1);
        chronic += (load - chronic) * 2 / (chronicDays + 1);
      }
    }

    return TrainingState(
      sessions: runs,
      thresholdPace: thresholdPace,
      thresholdFromRuns: candidates.length,
      fitness: fitness,
      fatigue: fatigue,
      acwr: chronic < 1 ? null : acute / chronic,
      bestRun: bestRun,
      predicted5k: bestRun == null
          ? null
          : riegel(bestRun.movingSeconds.toDouble(), bestRun.km, 5),
      predicted10k: bestTenK,
      loadByDay: loadByDay,
    );
  }

  // Riegel: d1 km를 t1초에 달렸다면 d2 km는 몇 초
  static double riegel(double t1, double d1, double d2) =>
      t1 * pow(d2 / d1, riegelExponent);

  static double intensityOf(Session s, double thresholdPace) {
    final double raw = (thresholdPace / s.pace).clamp(0.3, 1.2);
    return s.isWalk ? min(raw, walkMaxIntensity) : raw;
  }

  static double loadOf(Session s, double thresholdPace) {
    final double intensity = intensityOf(s, thresholdPace);
    return s.movingSeconds / 3600 * intensity * intensity * 100;
  }
}

class TrainingState {
  final List<Session> sessions; // 쓸 만한 것만, 오래된 것부터
  final double thresholdPace; // 분/km
  final int thresholdFromRuns; // 역치 추정에 쓴 러닝 수 (0이면 기본값)
  final double fitness;
  final double fatigue;
  final double? acwr; // 기록이 너무 적으면 null
  final Session? bestRun;
  final double? predicted5k; // 초
  final double? predicted10k; // 초
  final Map<DateTime, double> loadByDay;

  const TrainingState({
    required this.sessions,
    required this.thresholdPace,
    required this.thresholdFromRuns,
    required this.fitness,
    required this.fatigue,
    required this.acwr,
    required this.bestRun,
    required this.predicted5k,
    required this.predicted10k,
    required this.loadByDay,
  });

  double get form => fitness - fatigue;

  // ACWR 1.3 초과 또는 컨디션 -25 미만이면 무리하는 중
  bool get overreaching => (acwr ?? 0) > 1.3 || form < -25;

  // 오래 쉬다 돌아온 상태 (최근 부하가 평소의 80% 미만)
  bool get detraining => acwr != null && acwr! < 0.8;
}
