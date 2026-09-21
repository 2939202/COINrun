import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// 큰 숫자 + 작은 라벨 (나이키 런 스타일의 기록 표시). Row 안에서 칸을 나눠 씁니다.
class StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final CrossAxisAlignment alignment;

  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.alignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            value,
            style: textTheme.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: textTheme.labelMedium),
        ],
      ),
    );
  }
}
