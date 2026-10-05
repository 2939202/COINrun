import 'package:contact/game/pvp_battle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rookie = Fighter(id: 'a', name: '새내기', level: 1, totalKm: 0);
  const veteran = Fighter(id: 'b', name: '고수', level: 15, totalKm: 400);

  group('능력치', () {
    test('레벨과 거리가 높을수록 강하다', () {
      expect(veteran.maxHp, greaterThan(rookie.maxHp));
      expect(veteran.attack, greaterThan(rookie.attack));
      expect(veteran.power, greaterThan(rookie.power));
    });

    // 거리만으로 끝없이 강해지지 않게 체력의 거리 몫은 150에서 멈춥니다.
    test('체력의 거리 몫은 150까지', () {
      const a = Fighter(id: 'a', name: 'a', level: 1, totalKm: 300);
      const b = Fighter(id: 'b', name: 'b', level: 1, totalKm: 3000);
      expect(a.maxHp, b.maxHp);
    });
  });

  group('대결', () {
    test('누군가 쓰러지거나 최대 차례에서 끝난다', () {
      final result = PvpBattle.fight(rookie, veteran, seed: 1);
      final last = result.turns.last;
      expect(
        last.challengerHp == 0 ||
            last.opponentHp == 0 ||
            result.turns.length == PvpBattle.maxTurns,
        isTrue,
      );
    });

    test('체력은 0 아래로 내려가지 않는다', () {
      final result = PvpBattle.fight(rookie, veteran, seed: 2);
      for (final turn in result.turns) {
        expect(turn.challengerHp, greaterThanOrEqualTo(0));
        expect(turn.opponentHp, greaterThanOrEqualTo(0));
      }
    });

    test('차례는 번갈아 온다', () {
      final result = PvpBattle.fight(rookie, veteran, seed: 3);
      for (int i = 1; i < result.turns.length; i++) {
        expect(
          result.turns[i].byChallenger,
          isNot(result.turns[i - 1].byChallenger),
        );
      }
    });

    test('속도가 빠른 쪽이 먼저 친다', () {
      final result = PvpBattle.fight(rookie, veteran, seed: 4);
      expect(result.turns.first.byChallenger, isFalse);
    });

    test('씨앗이 같으면 결과도 같다 (같은 날 같은 상대)', () {
      final day = DateTime(2026, 10, 5);
      final seed = PvpBattle.seedFor(rookie, veteran, day);
      final a = PvpBattle.fight(rookie, veteran, seed: seed);
      final b = PvpBattle.fight(rookie, veteran, seed: seed);
      expect(a.challengerWon, b.challengerWon);
      expect(a.turns.length, b.turns.length);
    });

    test('실력 차이가 크면 강한 쪽이 거의 이긴다', () {
      int veteranWins = 0;
      for (int seed = 0; seed < 50; seed++) {
        if (!PvpBattle.fight(rookie, veteran, seed: seed).challengerWon) {
          veteranWins++;
        }
      }
      expect(veteranWins, greaterThanOrEqualTo(48));
    });

    test('비슷한 상대끼리는 승패가 갈린다', () {
      const a = Fighter(id: 'a', name: 'a', level: 5, totalKm: 30);
      const b = Fighter(id: 'b', name: 'b', level: 5, totalKm: 30);
      int wins = 0;
      for (int seed = 0; seed < 100; seed++) {
        if (PvpBattle.fight(a, b, seed: seed).challengerWon) wins++;
      }
      expect(wins, inInclusiveRange(25, 75));
    });
  });
}
