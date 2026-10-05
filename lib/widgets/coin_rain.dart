import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

// ============================================================
// 러닝 완료 리포트에서 금화가 위에서 쏟아져 바닥에 통통 튀는 효과
//
//   - 금화 개수는 받은 골드에 비례합니다. (coinCountFor)
//   - 한 번에 다 떨어지지 않고 조금씩 시차를 두고 떨어집니다.
//   - 바닥에 닿을 때마다 덜 튀어 오르다가 멈춥니다. (반발 계수)
//   - 떨어지면서 빙글빙글 돌아 동전 앞뒤가 뒤집히는 것처럼 보입니다.
//   - 다 멈추면 잠시 뒤 옅어지며 사라져서 리포트 글자를 가리지 않습니다.
//
// 금화가 처음 바닥에 닿을 때 onImpact를 부릅니다. 진동은 부르는 쪽에서 붙입니다.
// (이 위젯은 진동 플러그인을 몰라서 테스트에서도 그대로 쓸 수 있습니다)
//
// 터치는 막지 않습니다. 금화가 떨어지는 중에도 "확인"을 누를 수 있습니다.
// ============================================================
class CoinRain extends StatefulWidget {
  final int gold;
  final VoidCallback? onImpact;

  const CoinRain({super.key, required this.gold, this.onImpact});

  // 골드 20당 금화 1개, 최소 3개, 최대 60개. 골드가 0이면 하나도 안 떨어집니다.
  // 5km 러닝(약 600G)이면 30개쯤입니다.
  static int coinCountFor(int gold) {
    if (gold <= 0) return 0;
    return (gold / 20).ceil().clamp(3, 60);
  }

  @override
  State<CoinRain> createState() => _CoinRainState();
}

class _CoinRainState extends State<CoinRain>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  CoinRainSim? _sim;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (CoinRain.coinCountFor(widget.gold) > 0) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final CoinRainSim? sim = _sim;
    if (sim == null) return;
    // 프레임이 밀려도 한 번에 너무 많이 움직이지 않게 자릅니다.
    final double dt = min((elapsed - _last).inMicroseconds / 1e6, 1 / 30);
    _last = elapsed;
    final int impacts = sim.step(dt);
    if (impacts > 0) widget.onImpact?.call();
    if (sim.finished) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final int count = CoinRain.coinCountFor(widget.gold);
    if (count == 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size area = constraints.biggest;
          // 화면 크기를 알아야 바닥 위치를 정할 수 있어서 여기서 만듭니다.
          _sim ??= CoinRainSim(count: count, area: area, random: Random());
          return CustomPaint(size: area, painter: _CoinPainter(_sim!));
        },
      ),
    );
  }
}

// 금화 한 개
class FallingCoin {
  final double x;
  final double size;
  final double delay; // 이만큼(초) 기다렸다가 떨어지기 시작합니다.
  final double spinSpeed; // 동전이 뒤집히는 빠르기
  double y;
  double vy = 0;
  double spin = 0;
  bool landed = false; // 한 번이라도 바닥에 닿았는지 (진동을 처음 한 번만)
  bool resting = false; // 다 튀고 멈췄는지

  FallingCoin({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.spinSpeed,
  });
}

// 금화들의 움직임 계산. 화면과 떨어져 있어서 테스트할 수 있습니다.
class CoinRainSim {
  static const double gravity = 2600; // 픽셀/초²
  static const double bounce = 0.52; // 바닥에서 튀어 오르는 비율
  static const double restSpeed = 120; // 이보다 느리게 튀면 멈춘 것으로 봅니다.
  static const double holdSeconds = 1.2; // 다 멈춘 뒤 보여주는 시간
  static const double fadeSeconds = 0.6;

  final Size area;
  final List<FallingCoin> coins;
  double time = 0;
  double? _allRestAt;

  CoinRainSim({required int count, required this.area, required Random random})
    : coins = List.generate(count, (i) {
        final double size = 22 + random.nextDouble() * 14;
        return FallingCoin(
          x: random.nextDouble() * (area.width - size),
          y: -size - random.nextDouble() * 120,
          size: size,
          // 개수가 많아도 1.2초 안에 다 떨어지기 시작합니다.
          delay: count == 1 ? 0 : i / count * 1.2 + random.nextDouble() * 0.1,
          spinSpeed: 6 + random.nextDouble() * 8,
        );
      });

  // 금화가 바닥 바로 위에 쌓이지 않고 조금씩 다른 높이에 멈추게, 바닥을 살짝 흩뜨립니다.
  double floorFor(FallingCoin coin) =>
      area.height - coin.size - (coin.x * 7 % 18);

  // 0(투명) ~ 1(선명)
  double get opacity {
    final double? restAt = _allRestAt;
    if (restAt == null) return 1;
    final double t = (time - restAt - holdSeconds) / fadeSeconds;
    return (1 - t).clamp(0.0, 1.0);
  }

  bool get finished => opacity <= 0;

  // dt초만큼 움직이고, 이번에 처음 바닥에 닿은 금화 수를 돌려줍니다.
  int step(double dt) {
    time += dt;
    int impacts = 0;
    for (final coin in coins) {
      if (coin.resting || time < coin.delay) continue;
      coin.vy += gravity * dt;
      coin.y += coin.vy * dt;
      coin.spin += coin.spinSpeed * dt;

      final double floor = floorFor(coin);
      if (coin.y >= floor) {
        coin.y = floor;
        if (!coin.landed) {
          coin.landed = true;
          impacts++;
        }
        coin.vy = -coin.vy * bounce;
        if (coin.vy.abs() < restSpeed) {
          coin.vy = 0;
          coin.resting = true;
          // 앞면이 보이게 눕힙니다.
          coin.spin = (coin.spin / pi).roundToDouble() * pi;
        }
      }
    }
    if (_allRestAt == null && coins.every((coin) => coin.resting)) {
      _allRestAt = time;
    }
    return impacts;
  }
}

class _CoinPainter extends CustomPainter {
  final CoinRainSim sim;

  _CoinPainter(this.sim);

  static const Color _rim = Color(0xFF8A6212);
  static const Color _engraved = Color(0xFF7A520A);

  final TextPainter _g = TextPainter(
    text: const TextSpan(
      text: 'G',
      style: TextStyle(
        // 그림판(TextPainter)에는 앱 글꼴이 내려오지 않아서 직접 적습니다.
        fontFamily: AppTheme.hangulSerifFont,
        fontSize: 13,
        fontWeight: AppTheme.serifWeight,
        color: _engraved,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = sim.opacity;
    if (opacity <= 0) return;

    for (final coin in sim.coins) {
      if (sim.time < coin.delay) continue;
      final double r = coin.size / 2;
      canvas.save();
      canvas.translate(coin.x + r, coin.y + r);
      // 가로로 납작해졌다 돌아오면 동전이 뒤집히는 것처럼 보입니다.
      canvas.scale(max(cos(coin.spin).abs(), 0.12), 1);
      _paintCoin(canvas, r, opacity);
      canvas.restore();
    }
  }

  void _paintCoin(Canvas canvas, double r, double opacity) {
    final Rect bounds = Rect.fromCircle(center: Offset.zero, radius: r);
    final int alpha = (opacity * 255).round();

    // 바닥 그림자
    canvas.drawCircle(
      Offset(0, r * 0.12),
      r,
      Paint()..color = Color.fromARGB((alpha * 0.25).round(), 60, 40, 5),
    );
    // 금속 바탕: 왼쪽 위가 빛을 받아 밝고 오른쪽 아래가 짙습니다.
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF3B0),
            Color(0xFFF2CC4E),
            Color(0xFFC8961C),
            Color(0xFFF7DC6F),
            Color(0xFFA87A14),
          ],
          stops: [0, 0.3, 0.55, 0.72, 1],
        ).createShader(bounds)
        ..color = Color.fromARGB(alpha, 255, 255, 255),
    );
    // 바깥 테두리와 안쪽 원
    canvas.drawCircle(
      Offset.zero,
      r - 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _rim.withValues(alpha: opacity),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _engraved.withValues(alpha: 0.55 * opacity),
    );
    // 반사광 한 점
    canvas.drawCircle(
      Offset(-r * 0.38, -r * 0.4),
      r * 0.16,
      Paint()..color = Color.fromARGB((alpha * 0.7).round(), 255, 255, 255),
    );
    // 가운데 G
    canvas.save();
    final double scale = r / 11;
    canvas.scale(scale);
    if (opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromARGB(alpha, 255, 255, 255),
      );
    }
    _g.paint(canvas, Offset(-_g.width / 2, -_g.height / 2));
    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) => true;
}
