import 'package:contact/game/run_rules.dart';
import 'package:contact/models/ranking_entry.dart';
import 'package:contact/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('누적 경험치 계산', () {
    // exp는 레벨이 오를 때마다 0으로 돌아가서, 레벨만으로는 누가 앞섰는지 알 수 없습니다.
    test('Lv.1에서는 지금 경험치가 그대로 누적 경험치', () {
      expect(RunRules.totalExpFor(1, 0), 0);
      expect(RunRules.totalExpFor(1, 50), 50);
    });

    test('레벨업에 쓴 경험치를 모두 더한다', () {
      // Lv.1 -> 2에 100, 2 -> 3에 200
      expect(RunRules.totalExpFor(2, 0), 100);
      expect(RunRules.totalExpFor(3, 0), 300);
      expect(RunRules.totalExpFor(3, 150), 450);
    });

    test('경험치를 계속 더해 나간 값과 같다', () {
      int level = 1;
      int exp = 0;
      int given = 0;
      for (int i = 0; i < 40; i++) {
        final next = RunRules.addExp(level, exp, 137);
        level = next.level;
        exp = next.exp;
        given += 137;
      }
      expect(RunRules.totalExpFor(level, exp), given);
    });

    test('같은 레벨이어도 경험치가 많은 쪽이 앞선다', () {
      expect(
        RunRules.totalExpFor(5, 300),
        greaterThan(RunRules.totalExpFor(5, 299)),
      );
    });

    test('레벨이 높으면 항상 앞선다', () {
      // Lv.5에서 경험치가 거의 다 찬 사람보다 Lv.6 갓 된 사람이 위
      expect(
        RunRules.totalExpFor(6, 0),
        greaterThan(RunRules.totalExpFor(5, 499)),
      );
    });
  });

  group('랭킹 줄 읽기', () {
    test('Firestore 값을 읽어온다', () {
      final entry = RankingEntry.fromMap('uid1', {
        'nickname': '러너1호',
        'level': 7,
        'totalDistance': 42195.0,
        'totalExp': 2100,
      });

      expect(entry.userId, 'uid1');
      expect(entry.nickname, '러너1호');
      expect(entry.level, 7);
      expect(entry.totalDistance, 42195.0);
    });

    test('값이 빠져 있어도 앱이 죽지 않는다', () {
      final entry = RankingEntry.fromMap('uid1', {});
      expect(entry.nickname, '이름없음');
      expect(entry.level, 1);
      expect(entry.totalDistance, 0);
      expect(entry.totalExp, 0);
    });
  });

  group('랭킹 기준', () {
    test('거리는 totalDistance, 레벨은 totalExp로 줄을 세운다', () {
      expect(RankingKind.distance.field, 'totalDistance');
      expect(RankingKind.level.field, 'totalExp');
      expect(RankingKind.distance.label, '거리');
      expect(RankingKind.level.label, '레벨');
    });
  });

  group('랭킹을 붙이기 전 계정', () {
    // totalExp 필드가 없던 시절 문서도 순위에 끼워줘야 합니다.
    test('totalExp가 없으면 레벨과 경험치로 되짚어 구한다', () {
      final user = UserModel.fromMap({'level': 3, 'exp': 150});
      expect(user.totalExp, 450);
    });

    test('저장된 totalExp가 있으면 그 값을 쓴다', () {
      final user = UserModel.fromMap({'level': 3, 'exp': 150, 'totalExp': 999});
      expect(user.totalExp, 999);
    });

    test('저장한 값을 그대로 다시 읽어온다', () {
      final user = UserModel.initial('러너1호');
      expect(UserModel.fromMap(user.toMap()).totalExp, 0);
    });
  });
}
