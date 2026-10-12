import 'dart:math';

import 'package:flutter/material.dart';

// ============================================================
// 보물 지도 덧칠 (러닝 화면 지도 위)
//
// 지도 색은 widgets/map_tiles.dart의 treasureLayers()가 양피지색으로 바꾸고,
// 여기서는 그 위에 두 가지를 얹습니다.
//   1. 네 변으로 갈수록 어두워지는 비네팅. 오래 펼쳐 본 종이 가장자리처럼 탑니다.
//   2. 아주 옅은 종이 결(작은 점). 고정된 씨앗으로 찍어서 다시 그려도 그대로입니다.
//
// 가운데는 거의 건드리지 않아서 경로와 코인은 그대로 읽힙니다.
// 손가락은 받지 않습니다. (IgnorePointer) 지도를 끌고 넓히는 데 방해가 되지 않습니다.
// ============================================================
class TreasureMapOverlay extends StatelessWidget {
  const TreasureMapOverlay({super.key});

  // 탄 종이 가장자리 색
  static const Color burnt = Color(0xFF4A3420);

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _TreasurePainter(), size: Size.infinite),
      ),
    );
  }
}

class _TreasurePainter extends CustomPainter {
  const _TreasurePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // 1) 종이 결: 화면 넓이에 비례해 점을 찍습니다.
    final Random random = Random(7);
    final Paint grain = Paint();
    final int count = (size.width * size.height / 90).round();
    for (int i = 0; i < count; i++) {
      final double dark = random.nextDouble();
      grain.color = TreasureMapOverlay.burnt.withValues(
        alpha: 0.025 + 0.04 * dark,
      );
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.5 + random.nextDouble() * 0.7,
        grain,
      );
    }

    // 2) 네 변 비네팅: 가장자리 28px 안쪽에서 진하고, 안으로 들어올수록 사라집니다.
    const double band = 28;
    const Color edge = Color(0x404A3420);
    const Color clear = Color(0x004A3420);
    void side(Rect area, Alignment from, Alignment to) {
      canvas.drawRect(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: from,
            end: to,
            colors: const [edge, clear],
          ).createShader(area),
      );
    }

    side(
      Rect.fromLTWH(0, 0, size.width, band),
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    side(
      Rect.fromLTWH(0, size.height - band, size.width, band),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );
    side(
      Rect.fromLTWH(0, 0, band, size.height),
      Alignment.centerLeft,
      Alignment.centerRight,
    );
    side(
      Rect.fromLTWH(size.width - band, 0, band, size.height),
      Alignment.centerRight,
      Alignment.centerLeft,
    );

    // 3) 모서리는 한 번 더 둥글게 어둡게 (가운데는 투명)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0x004A3420), Color(0x004A3420), Color(0x284A3420)],
          stops: [0, 0.62, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_TreasurePainter oldDelegate) => false;
}
