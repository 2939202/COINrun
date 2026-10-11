import 'dart:math';

// ============================================================
// 게임 플레잉(PVP) - 두 러너가 번갈아 공격하는 자동 대결
//
// [능력치는 달린 만큼]
//   레벨과 누적 거리로만 정합니다. 상대의 장비는 랭킹 목록(leaderboard)에 없어서
//   양쪽 모두 장비는 빼고 계산합니다. (공평하게)
//
//   체력 = 100 + 레벨×12 + 누적km×0.5 (거리 몫은 최대 150)
//   공격 = 10 + 레벨×2 + √누적km×1.5
//   방어 = 4 + 레벨
//   속도 = 레벨 + √누적km  -> 높은 쪽이 먼저 칩니다
//
//   누적 거리는 제곱근을 씌워서, 많이 뛴 사람이 유리하되 한없이 강해지지는 않게 했습니다.
//
// [같은 상대와는 하루 동안 같은 결과]
//   주사위(Random)의 씨앗을 두 사람과 날짜로 정해서, 다시 붙어도 오늘은 결과가 같습니다.
//   계속 다시 해서 이길 때까지 돌리는 것을 막고, 테스트도 할 수 있습니다.
//
// 지금은 연습 대결입니다. 이겨도 골드나 경험치를 주지 않습니다.
// (보상을 붙이려면 서버에서 계산해야 조작을 막을 수 있습니다)
// ============================================================
class Fighter {
  final String id;
  final String name;
  final int level;
  final double totalKm;

  const Fighter({
    required this.id,
    required this.name,
    required this.level,
    required this.totalKm,
  });

  int get maxHp => 100 + level * 12 + min(totalKm * 0.5, 150).round();
  double get attack => 10 + level * 2 + sqrt(totalKm) * 1.5;
  double get defense => 4.0 + level;
  double get speed => level + sqrt(totalKm);

  // 목록에 보여줄 전투력 한 숫자
  int get power => (maxHp * 0.5 + attack * 3 + defense * 2).round();
}

class BattleTurn {
  final bool byChallenger; // 도전자(나)가 친 차례인지
  final int damage;
  final bool critical;
  final bool dodged;
  final int challengerHp; // 이 차례가 끝난 뒤 남은 체력
  final int opponentHp;

  const BattleTurn({
    required this.byChallenger,
    required this.damage,
    required this.critical,
    required this.dodged,
    required this.challengerHp,
    required this.opponentHp,
  });
}

class BattleResult {
  final Fighter challenger;
  final Fighter opponent;
  final List<BattleTurn> turns;
  final bool challengerWon;

  const BattleResult({
    required this.challenger,
    required this.opponent,
    required this.turns,
    required this.challengerWon,
  });
}

class PvpBattle {
  PvpBattle._();

  static const int maxTurns = 40;
  static const double criticalChance = 0.12;
  static const double criticalMultiplier = 1.7;
  static const double dodgeChance = 0.08;

  static int seedFor(Fighter a, Fighter b, DateTime day) =>
      Object.hash(a.id, b.id, day.year, day.month, day.day);

  static BattleResult fight(Fighter challenger, Fighter opponent, {int? seed}) {
    final Random random = Random(
      seed ?? seedFor(challenger, opponent, DateTime.now()),
    );
    int myHp = challenger.maxHp;
    int theirHp = opponent.maxHp;
    final List<BattleTurn> turns = [];

    // 속도가 같으면 도전자가 먼저
    bool myTurn = challenger.speed >= opponent.speed;

    while (myHp > 0 && theirHp > 0 && turns.length < maxTurns) {
      final Fighter attacker = myTurn ? challenger : opponent;
      final Fighter defender = myTurn ? opponent : challenger;

      final bool dodged = random.nextDouble() < dodgeChance;
      final bool critical = !dodged && random.nextDouble() < criticalChance;
      int damage = 0;
      if (!dodged) {
        final double swing = 0.85 + random.nextDouble() * 0.3; // ±15%
        double raw = attacker.attack * swing - defender.defense * 0.5;
        if (critical) raw *= criticalMultiplier;
        damage = max(1, raw.round());
      }

      if (myTurn) {
        theirHp = max(0, theirHp - damage);
      } else {
        myHp = max(0, myHp - damage);
      }
      turns.add(
        BattleTurn(
          byChallenger: myTurn,
          damage: damage,
          critical: critical,
          dodged: dodged,
          challengerHp: myHp,
          opponentHp: theirHp,
        ),
      );
      myTurn = !myTurn;
    }

    // 끝까지 안 끝나면 남은 체력 비율이 높은 쪽이 이깁니다.
    final bool won = theirHp == 0
        ? true
        : myHp == 0
        ? false
        : myHp / challenger.maxHp >= theirHp / opponent.maxHp;

    return BattleResult(
      challenger: challenger,
      opponent: opponent,
      turns: turns,
      challengerWon: won,
    );
  }
}
