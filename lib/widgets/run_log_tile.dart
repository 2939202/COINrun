import 'package:flutter/material.dart';

import '../models/run_log.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

// 목록에서 기록을 치웠을 때 어떻게 치웠는지
enum RunRemoval {
  hide, // 목록에서만 감춤. 통계는 그대로
  delete, // 정말 지움. 통계에서도 빼냄
}

// ============================================================
// 러닝 기록 한 줄. 홈의 "최근 러닝"과 전체 기록 화면에서 같이 씁니다.
//
// 오른쪽으로 밀면 치울 수 있습니다. 실수로 시작을 눌러 생긴 0km 기록처럼
// 남겨둬야 의미가 없는 것을 없애기 위해서입니다.
//
// 미는 것만으로 바로 없애지 않고 물어봅니다. 감추는 것과 지우는 것은 결과가 다릅니다.
//   감춤 - 목록에서만 사라짐. 주간/월간 기록에는 그대로 남음
//   삭제 - 경로까지 지우고 주간/월간 기록에서도 빠짐
// ============================================================
class RunLogTile extends StatelessWidget {
  final RunLog run;
  final VoidCallback onTap;

  // null이면 밀어서 치우기를 쓰지 않습니다.
  final Future<void> Function(RunRemoval how)? onRemove;

  const RunLogTile({
    super.key,
    required this.run,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final Widget row = _buildRow(context);
    if (onRemove == null) return row;

    return Dismissible(
      key: ValueKey(run.id),
      // 오른쪽으로 미는 것만 받습니다. 왼쪽으로 미는 것은 뒤로 가기와 헷갈립니다.
      direction: DismissDirection.startToEnd,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppColors.white),
            SizedBox(width: AppSpacing.sm),
            Text('치우기', style: TextStyle(color: AppColors.white)),
          ],
        ),
      ),
      // 항상 false를 돌려줘서 줄이 제자리로 돌아오게 합니다.
      // 실제로 치우는 일은 우리가 하고, 목록은 저장소가 바뀌면 알아서 다시 그려집니다.
      confirmDismiss: (_) async {
        final RunRemoval? how = await _ask(context);
        if (how != null) await onRemove!(how);
        return false;
      },
      child: row,
    );
  }

  Future<RunRemoval?> _ask(BuildContext context) {
    return showDialog<RunRemoval>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 기록을 치울까요?'),
        content: const Text(
          '감추면 목록에서만 사라지고, 주간·월간 기록에는 그대로 남습니다.\n\n'
          '삭제하면 지나온 길까지 지워지고 주간·월간 기록에서도 빠집니다. '
          '나중에 이 기간을 돌아볼 때 이 러닝은 없던 것이 됩니다.\n\n'
          '이미 받은 골드와 경험치는 어느 쪽이든 그대로 남습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, RunRemoval.delete),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
          // 되돌릴 수 있는 쪽을 오른쪽 끝(누르기 쉬운 자리)에 둡니다.
          ElevatedButton(
            onPressed: () => Navigator.pop(context, RunRemoval.hide),
            child: const Text('감추기'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
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
