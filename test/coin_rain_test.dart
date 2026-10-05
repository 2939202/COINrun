import 'dart:math';

import 'package:contact/widgets/coin_rain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('금화 개수', () {
    test('골드가 없으면 안 떨어진다', () {
      expect(CoinRain.coinCountFor(0), 0);
    });

    test('골드가 적어도 최소 3개는 떨어진다', () {
      expect(CoinRain.coinCountFor(5), 3);
    });

    test('골드에 비례한다 (20G당 1개)', () {
      expect(CoinRain.coinCountFor(600), 30);
      expect(CoinRain.coinCountFor(1000), 50);
    });

    test('너무 많으면 60개에서 멈춘다', () {
      expect(CoinRain.coinCountFor(100000), 60);
    });
  });

  group('금화 움직임', () {
    CoinRainSim sim() =>
        CoinRainSim(count: 30, area: const Size(400, 800), random: Random(1));

    test('모든 금화가 한 번씩 바닥에 닿고, 닿을 때마다 한 번만 센다', () {
      final s = sim();
      int impacts = 0;
      for (int i = 0; i < 60 * 6; i++) {
        impacts += s.step(1 / 60);
      }
      expect(impacts, 30);
    });

    test('바닥 아래로 빠지지 않는다', () {
      final s = sim();
      for (int i = 0; i < 60 * 6; i++) {
        s.step(1 / 60);
        for (final coin in s.coins) {
          expect(coin.y, lessThanOrEqualTo(s.floorFor(coin) + 0.001));
        }
      }
    });

    test('튀다가 멈추고, 잠시 뒤 사라진다', () {
      final s = sim();
      for (int i = 0; i < 60 * 8; i++) {
        s.step(1 / 60);
      }
      expect(s.coins.every((coin) => coin.resting), isTrue);
      expect(s.finished, isTrue);
    });
  });

  testWidgets('금화가 떨어지는 동안에도 아래 버튼을 누를 수 있다', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Center(
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('확인'),
              ),
            ),
            const Positioned.fill(child: CoinRain(gold: 600)),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('확인'));
    expect(taps, 1);
    // 애니메이션이 끝날 때까지 돌려서 남은 타이머가 없게 합니다.
    await tester.pumpAndSettle();
  });
}
