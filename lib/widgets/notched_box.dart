import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ============================================================
// 모서리를 잘라낸 팔각형 카드
//
// 네 모서리를 모두 45도로 잘라냅니다. 둥근 구석이 하나도 없어서
// 표나 입장권 같은 인상이 납니다. 검은 카드에 공통으로 씁니다.
//
//      ╱────────╲
//      │        │
//      ╲────────╱
// ============================================================
class NotchedBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  // 잘라내는 크기
  final double cut;

  // 안쪽에 그리는 테두리. 같은 팔각형 모양으로 한 겹 안에 들어갑니다.
  final Color? innerBorderColor;
  final double innerBorderInset;

  const NotchedBox({
    super.key,
    required this.child,
    this.color = AppColors.black,
    this.padding,
    this.onTap,
    this.cut = 16,
    this.innerBorderColor,
    this.innerBorderInset = 7,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(padding: padding ?? EdgeInsets.zero, child: child);

    if (innerBorderColor != null) {
      body = CustomPaint(
        foregroundPainter: _InnerBorderPainter(
          cut: cut,
          inset: innerBorderInset,
          color: innerBorderColor!,
        ),
        child: body,
      );
    }

    return ClipPath(
      clipper: _NotchedClipper(cut: cut),
      child: Material(
        color: color,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

// 네 모서리를 자른 팔각형
Path _octagon(Size size, double cut) {
  final double w = size.width;
  final double h = size.height;
  // 카드가 아주 작아도 모양이 깨지지 않게 줄여 잡습니다.
  final double c = cut.clamp(0, size.shortestSide / 2);

  return Path()
    ..moveTo(c, 0)
    ..lineTo(w - c, 0)
    ..lineTo(w, c)
    ..lineTo(w, h - c)
    ..lineTo(w - c, h)
    ..lineTo(c, h)
    ..lineTo(0, h - c)
    ..lineTo(0, c)
    ..close();
}

class _NotchedClipper extends CustomClipper<Path> {
  final double cut;

  const _NotchedClipper({required this.cut});

  @override
  Path getClip(Size size) => _octagon(size, cut);

  @override
  bool shouldReclip(_NotchedClipper old) => old.cut != cut;
}

// 카드 안쪽에 한 겹 더 그리는 테두리
class _InnerBorderPainter extends CustomPainter {
  final double cut;
  final double inset;
  final Color color;

  const _InnerBorderPainter({
    required this.cut,
    required this.inset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Size inner = Size(size.width - inset * 2, size.height - inset * 2);
    if (inner.width <= 0 || inner.height <= 0) return;

    canvas.save();
    canvas.translate(inset, inset);
    canvas.drawPath(
      _octagon(inner, cut - inset / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerBorderPainter old) =>
      old.cut != cut || old.inset != inset || old.color != color;
}

// ============================================================
// 점선 테두리 상자 (기록이 없을 때의 빈 자리)
// ============================================================
class DashedBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DashedBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.sand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.sm),
    );

    // 테두리를 따라가면서 그렸다 쉬었다 반복합니다.
    const double dash = 6;
    const double gap = 5;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      double at = 0;
      while (at < metric.length) {
        final double end = (at + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(at, end), paint);
        at = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter oldDelegate) => false;
}
