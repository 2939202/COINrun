import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ============================================================
// 칸칸이 끊어진 막대
//
// 경험치와 능력치를 같은 모양으로 보여줍니다.
// 이어진 막대보다 눈금이 있는 쪽이 "얼마나 찼는지"가 또렷하게 읽힙니다.
// ============================================================
class SegmentBar extends StatelessWidget {
  final double progress;

  // 채워진 칸과 빈 칸의 색
  final Color filledColor;
  final Color emptyColor;
  final double height;

  // 칸 개수. 시안과 같은 촘촘함을 내려고 19칸으로 잡았습니다.
  static const int count = 19;

  const SegmentBar({
    super.key,
    required this.progress,
    this.filledColor = AppColors.accent,
    this.emptyColor = AppColors.inkSoft,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final int filled = (progress * count).round();
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < filled ? filledColor : emptyColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
