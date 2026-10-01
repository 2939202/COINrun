import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../models/course.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

// ============================================================
// 코스 화면을 이루는 조각들
//   CourseCard        - 정사각형 코스 카드 (한 줄에 세 장)
//   CourseSectionHead - "CLASSIC / 클래식 코스 ... 전체보기"
//   TearLine          - 클래식과 사설 사이의 절취선 (점선)
// ============================================================

// 한 줄에 놓는 카드 수. 클래식 9장 = 3줄, 사설 3장 = 1줄
const int courseGridColumns = 3;

class CourseGrid extends StatelessWidget {
  final List<Course> courses;
  final String? selectedId;
  final ValueChanged<Course> onTap;

  const CourseGrid({
    super.key,
    required this.courses,
    required this.onTap,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: courseGridColumns,
      mainAxisSpacing: AppSpacing.sm + 2,
      crossAxisSpacing: AppSpacing.sm + 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (final course in courses)
          CourseCard(
            course: course,
            selected: course.id == selectedId,
            onTap: () => onTap(course),
          ),
      ],
    );
  }
}

// 정사각형 코스 카드. 위에는 코스 모양, 아래에는 이름과 거리.
// 지금 골라둔 코스는 검은 카드로 뒤집어 보여줍니다.
class CourseCard extends StatelessWidget {
  final Course course;
  final bool selected;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppColors.black
        : (course.official ? AppColors.cream : AppColors.white);
    final Color ink = selected ? AppColors.white : AppColors.black;
    final Color sub = selected ? AppColors.sandOnDark : AppColors.label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          border: Border.all(color: AppColors.black, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: CourseShapePainter(
                  points: course.points,
                  color: ink,
                  background: background,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              course.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.serifNumber.copyWith(
                fontSize: 12.5,
                height: 1.2,
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '${formatKm(course.distanceMeters)}km',
                  style: AppTheme.sans.copyWith(fontSize: 11, color: sub),
                ),
                if (!course.official) ...[
                  const Spacer(),
                  Icon(Icons.favorite, size: 11, color: sub),
                  const SizedBox(width: 2),
                  Text(
                    '${course.hearts}',
                    style: AppTheme.sans.copyWith(fontSize: 11, color: sub),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 코스 모양을 칸에 꽉 차게 그립니다. 지도 없이 선만 그려서 카드 아홉 장이어도 가볍습니다.
// 출발은 속이 빈 점, 도착은 꽉 찬 점입니다.
class CourseShapePainter extends CustomPainter {
  final List<LatLng> points;
  final Color color;
  final Color background;

  const CourseShapePainter({
    required this.points,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;

    // 위도 1도와 경도 1도의 실제 길이가 달라서, 경도에 cos(위도)를 곱해 모양을 맞춥니다.
    final double lat0 = points.first.latitude * pi / 180;
    final List<Offset> raw = [
      for (final p in points) Offset(p.longitude * cos(lat0), -p.latitude),
    ];
    double minX = raw.first.dx, maxX = raw.first.dx;
    double minY = raw.first.dy, maxY = raw.first.dy;
    for (final o in raw) {
      minX = min(minX, o.dx);
      maxX = max(maxX, o.dx);
      minY = min(minY, o.dy);
      maxY = max(maxY, o.dy);
    }

    const double inset = 6;
    final double w = max(maxX - minX, 1e-9);
    final double h = max(maxY - minY, 1e-9);
    final double scale = min(
      (size.width - inset * 2) / w,
      (size.height - inset * 2) / h,
    );
    // 가운데 정렬
    final double offsetX = (size.width - w * scale) / 2;
    final double offsetY = (size.height - h * scale) / 2;
    final List<Offset> pts = [
      for (final o in raw)
        Offset(
          offsetX + (o.dx - minX) * scale,
          offsetY + (o.dy - minY) * scale,
        ),
    ];

    final Path path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 왕복 코스는 출발과 도착이 겹칩니다. 도착을 먼저 그리고 출발을 위에 얹습니다.
    canvas.drawCircle(pts.last, 3.4, Paint()..color = color);
    canvas.drawCircle(pts.first, 3.4, Paint()..color = background);
    canvas.drawCircle(
      pts.first,
      3.4,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(CourseShapePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.background != background;
}

// 영문 소제목 + 한글 제목 + 오른쪽 "전체보기"
class CourseSectionHead extends StatelessWidget {
  final String caption;
  final String title;
  final VoidCallback? onSeeAll;

  const CourseSectionHead({
    super.key,
    required this.caption,
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              caption,
              style: AppTheme.caption.copyWith(
                fontFamily: AppTheme.sansFont,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: AppTheme.serifNumber.copyWith(
                fontSize: 20,
                color: AppColors.black,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              '전체보기',
              style: AppTheme.sans.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.accent,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent,
              ),
            ),
          ),
      ],
    );
  }
}

// 절취선. 점선이 끝에서 끝까지 이어집니다.
class TearLine extends StatelessWidget {
  const TearLine({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.fromHeight(1.4),
      painter: _DashLinePainter(),
    );
  }
}

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.label
      ..strokeWidth = 1.4;
    const double dash = 6;
    const double gap = 4;
    final double y = size.height / 2;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter oldDelegate) => false;
}

// 코스가 없을 때 그리드 자리에 넣는 안내
class CourseEmpty extends StatelessWidget {
  final String message;

  const CourseEmpty({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: AppColors.sand, width: 1.2),
      ),
      child: Text(
        message,
        style: AppTheme.sans.copyWith(fontSize: 13, color: AppColors.label),
      ),
    );
  }
}

// 오른쪽에서 밀려 들어오는 화면 전환
Route<T> slideFromRight<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<Offset> offset = Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
      return SlideTransition(position: offset, child: child);
    },
  );
}
