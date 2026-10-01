import '../models/equipment_set.dart';
import '../models/run_record.dart';
import 'equipment_rules.dart';

// ============================================================
// 게임 규칙: 러닝 기록 -> 골드/경험치/레벨
// 보상 기준을 바꿀 때는 이 파일만 고치면 됩니다.
//
//   - 경험치: 실제로 움직인 시간 1분당 10 EXP  (Lv.1 -> 2는 약 10분)
//   - 골드: 10걸음당 1골드                     (5km 러닝 약 6,000걸음 -> 600골드)
//
// 입고 있는 장비 세트가 있으면 여기에 보너스가 더 붙습니다.
// 보너스 계산은 game/equipment_rules.dart가 담당합니다.
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

  // gear: 러닝을 마친 시점에 입고 있던 장비 세트. 맨몸이면 null입니다.
  static int expFor(RunRecord run, {EquipmentSet? gear}) {
    final int base = run.movingTime.inSeconds * expPerMovingMinute ~/ 60;
    return EquipmentRules.applyExpBonus(base, gear);
  }

  static int goldFor(RunRecord run, {EquipmentSet? gear}) {
    final int base = run.steps ~/ stepsPerGold;
    return EquipmentRules.applyGoldBonus(base, gear);
  }

  // 코스 러닝은 걸음이 아니라 먹은 코인으로 골드를 줍니다. (game/course_coins.dart)
  // 걸음 골드와 같이 주면 두 번 쌓이므로 둘 중 하나만 씁니다.
  static int courseGoldFor(int coinGold, {EquipmentSet? gear}) {
    return EquipmentRules.applyGoldBonus(coinGold, gear);
  }

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

  // 지금까지 받은 경험치를 전부 합한 값
  //
  // exp는 레벨이 오를 때마다 0으로 돌아가기 때문에, 레벨 랭킹을 매기려면
  // "여태 얼마나 받았는가"를 따로 구해야 합니다. Lv.1->2가 100, 2->3이 200...이므로
  // 지금 레벨 전까지 필요했던 양을 모두 더하고 지금 레벨에서 쌓인 만큼을 더합니다.
  //
  // 경험치 랭킹을 레벨 대신 쓰는 이유: 같은 레벨이어도 누가 더 앞섰는지 가릴 수 있고,
  // 숫자 하나로 줄 세울 수 있어서 순위를 세는 질의가 단순해집니다.
  static int totalExpFor(int level, int exp) {
    // 100 + 200 + ... + (level-1)*100
    final int spent = 100 * (level - 1) * level ~/ 2;
    return spent + exp;
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
