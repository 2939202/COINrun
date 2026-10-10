import 'package:contact/game/run_load.dart';
import 'package:contact/game/training_model.dart';
import 'package:contact/models/run_record.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime now = DateTime(2026, 10, 9, 18);

RunRecord _run(double km, double pace, {int cadence = 165}) {
  final Duration t = Duration(seconds: (km * pace * 60).round());
  return RunRecord(
    elapsed: t,
    movingTime: t,
    distanceMeters: km * 1000,
    steps: (cadence * t.inSeconds / 60).round(),
    stepsEstimated: false,
  );
}

// 6분 페이스로 꾸준히 뛴 지난 기록 (역치 약 6.5분/km로 추정됨)
final List<Session> history = [
  for (int i = 1; i <= 12; i++)
    Session(
      day: DateTime(2026, 10, 9 - i * 2),
      km: 5,
      movingSeconds: 1800,
      steps: 165 * 30,
    ),
];

void main() {
  test('짧고 가벼운 조깅은 1', () {
    final load = RunLoad.of(_run(2, 7.5), history, now: now);
    expect(load.level, 1);
    expect(load.label, '가벼움');
  });

  test('평소 페이스로 5km는 2~3', () {
    final load = RunLoad.of(_run(5, 6.5), history, now: now);
    expect(load.level, inInclusiveRange(2, 3));
  });

  test('역치 근처로 1시간 가까이 뛰면 4', () {
    final load = RunLoad.of(_run(9.5, 6.3), history, now: now);
    expect(load.level, 4);
  });

  test('빠르게 오래(15km) 뛰면 5', () {
    final load = RunLoad.of(_run(15, 6.0), history, now: now);
    expect(load.level, 5);
  });

  test('같은 거리라도 평소보다 빠르면 부하가 크다 (사람마다 기준이 다름)', () {
    final easy = RunLoad.of(_run(5, 7.5), history, now: now);
    final hard = RunLoad.of(_run(5, 5.8), history, now: now);
    expect(hard.load, greaterThan(easy.load));
  });

  test('걸으면 강도를 낮게 본다', () {
    final load = RunLoad.of(_run(3, 6.5, cadence: 110), history, now: now);
    expect(load.walk, isTrue);
    expect(load.intensity, lessThanOrEqualTo(0.6));
  });

  test('기록이 없어도 입문 기준으로 계산한다', () {
    final load = RunLoad.of(_run(3, 7), const [], now: now);
    expect(load.thresholdFromRuns, 0);
    expect(load.thresholdPace, TrainingModel.defaultThresholdPace);
    expect(load.load, greaterThan(0));
  });

  test('거의 안 움직였으면 0 (1단계)', () {
    final load = RunLoad.of(_run(0.05, 6), history, now: now);
    expect(load.load, 0);
    expect(load.level, 1);
  });

  test('저장 값', () {
    final map = RunLoad.of(_run(5, 6.5), history, now: now).toMap();
    expect(
      map.keys,
      containsAll(['load', 'loadLevel', 'intensity', 'thresholdPace']),
    );
  });
}
