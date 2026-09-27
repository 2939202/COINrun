import 'package:flutter/material.dart';

import '../models/run_log.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

// 러닝 기록 한 줄. 홈의 "최근 러닝"과 전체 기록 화면에서 같이 씁니다.
class RunLogTile extends StatelessWidget {
  final RunLog run;
  final VoidCallback onTap;

  const RunLogTile({super.key, required this.run, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final DateTime? date = run.createdAt;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_run, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatKm(run.distanceMeters)} km',
                    style: textTheme.titleMedium,
                  ),
                  Text(
                    '${date == null ? '방금' : formatMonthDay(date)} · '
                    '${formatDuration(Duration(seconds: run.durationSeconds))}',
                    style: textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Text('+${run.goldEarned} G', style: textTheme.titleMedium),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.grey500),
          ],
        ),
      ),
    );
  }
}
