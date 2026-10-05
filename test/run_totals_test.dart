import 'package:contact/game/run_totals.dart';
import 'package:contact/models/run_log.dart';
import 'package:contact/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final user = UserModel.fromMap({
    'totalDistance': 10000.0,
    'totalRunSeconds': 3600,
    'totalMovingSeconds': 3000,
    'totalSteps': 12000,
  });
  final run = RunLog.fromMap('run1', {
    'distanceMeters': 4000.0,
    'durationSeconds': 1500,
    'movingSeconds': 1200,
    'steps': 5000,
  });

  group('기록 삭제/되살리기와 누적 기록', () {
    test('삭제하면 총 거리·시간·걸음에서 뺀다', () {
      final totals = RunTotals.apply(user, run, -1);
      expect(totals.distanceMeters, 6000);
      expect(totals.runSeconds, 2100);
      expect(totals.movingSeconds, 1800);
      expect(totals.steps, 7000);
    });

    test('되살리면 다시 더한다', () {
      final totals = RunTotals.apply(user, run, 1);
      expect(totals.distanceMeters, 14000);
      expect(totals.runSeconds, 5100);
    });

    // 누적 기록을 붙이기 전의 옛 기록을 지우면 원래보다 많이 뺄 수 있습니다.
    test('0 아래로 내려가지 않는다', () {
      final empty = UserModel.fromMap({});
      final totals = RunTotals.apply(empty, run, -1);
      expect(totals.distanceMeters, 0);
      expect(totals.runSeconds, 0);
      expect(totals.movingSeconds, 0);
      expect(totals.steps, 0);
    });

    test('users 문서에 쓸 필드 이름이 UserModel과 같다', () {
      final map = RunTotals.apply(user, run, -1).toMap();
      final reread = UserModel.fromMap(map);
      expect(reread.totalDistance, 6000);
      expect(reread.totalRunSeconds, 2100);
      expect(reread.totalMovingSeconds, 1800);
      expect(reread.totalSteps, 7000);
    });
  });
}
