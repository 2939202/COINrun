import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ============================================================
// 모서리가 잘린 카드
//
// 오른쪽 위와 왼쪽 아래를 45도로 잘라내고, 나머지 두 모서리는 둥글게 둡니다.
// 표나 입장권 같은 느낌이 나서, 이 앱의 검은 카드와 큰 버튼에 공통으로 씁니다.
//
//      ╭──────────╱
//      │          │
//      ╱──────────╯
// ============================================================
class NotchedBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  // 잘라내는 크기와 둥근 정도
  final double cut;
  final double radius;

  const NotchedBox({
    super.key,
    required this.child,
    this.color = AppColors.black,
    this.padding,
    this.onTap,
    this.cut = 18,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final Widget body = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    return ClipPath(
      clipper: _NotchedClipper(cut: cut, radius: radius),
      child: Material(
        color: color,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

class _NotchedClipper extends CustomClipper<Path> {
  final double cut;
  final double radius;

  const _NotchedClipper({required this.cut, required this.radius});

  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    // 카드가 아주 작아도 모양이 깨지지 않게 줄여 잡습니다.
    final double c = cut.clamp(0, size.shortestSide / 2);
    final double r = radius.clamp(0, size.shortestSide / 2);

    return Path()
      ..moveTo(r, 0)
      ..lineTo(w - c, 0) // 위쪽
      ..lineTo(w, c) // 오른쪽 위 - 잘림
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r)) // 오른쪽 아래 - 둥글게
      ..lineTo(c, h) // 아래쪽
      ..lineTo(0, h - c) // 왼쪽 아래 - 잘림
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r)) // 왼쪽 위 - 둥글게
      ..close();
  }

  @override
  bool shouldReclip(_NotchedClipper old) =>
      old.cut != cut || old.radius != radius;
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
