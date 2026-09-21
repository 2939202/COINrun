import '../models/run_record.dart';

// ============================================================
// 게임 규칙: 러닝 기록 -> 골드/경험치/레벨
// 보상 기준을 바꿀 때는 이 파일만 고치면 됩니다.
//
//   - 경험치: 실제로 움직인 시간 1분당 10 EXP  (Lv.1 -> 2는 약 10분)
//   - 골드: 10걸음당 1골드                     (5km 러닝 약 6,000걸음 -> 600골드)
// ============================================================

// 러닝 한 번으로 얻은 보상 (완료 리포트에 표시)
class RunReward {
  final int gold;
  final int exp;
  final int levelBefore;
  final int levelAfter;

  const RunReward({
    required this.gold,
    required this.exp,
    required this.levelBefore,
    required this.levelAfter,
  });

  bool get leveledUp => levelAfter > levelBefore;
}

class RunRules {
  RunRules._();

  static const int expPerMovingMinute = 10;
  static const int stepsPerGold = 10;

  static int expFor(RunRecord run) =>
      run.movingTime.inSeconds * expPerMovingMinute ~/ 60;

  static int goldFor(RunRecord run) => run.steps ~/ stepsPerGold;

  // 다음 레벨까지 필요한 경험치
  static int expToNextLevel(int level) => level * 100;

  // 경험치를 더하고 레벨업을 처리합니다. 한 번에 여러 레벨이 오를 수도 있어서 while로 반복합니다.
  static ({int level, int exp}) addExp(int level, int exp, int gained) {
    int newLevel = level;
    int newExp = exp + gained;
    while (newExp >= expToNextLevel(newLevel)) {
      newExp -= expToNextLevel(newLevel);
      newLevel += 1;
    }
    return (level: newLevel, exp: newExp);
  }

  // 레벨에 따른 등급 이름
  static String tierName(int level) {
    if (level >= 10) return '다이아 러너';
    if (level >= 7) return '플래티넘 러너';
    if (level >= 5) return '골드 러너';
    if (level >= 3) return '실버 러너';
    return '브론즈 러너';
  }
}
