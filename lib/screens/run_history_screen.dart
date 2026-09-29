import 'package:flutter/material.dart';

import '../models/run_log.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/run_log_tile.dart';
import 'run_detail_screen.dart';

// ============================================================
// 전체 러닝 기록
//
// 홈에는 최근 몇 개만 보이고, 여기서 보관 중인 것을 전부 봅니다.
// 보관 개수에 상한이 있어서(UserRepository.maxStoredRuns) 한 번에 다 읽어도 됩니다.
// 나중에 상한을 크게 올리면 그때 나눠서 읽도록 바꿔야 합니다.
// ============================================================
class RunHistoryScreen extends StatefulWidget {
  final String userId;

  const RunHistoryScreen({super.key, required this.userId});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  // 스트림은 한 번만 만들어 둡니다.
  late final Stream<List<RunLog>> _runs = UserRepository.instance
      .watchRecentRuns(widget.userId, limit: UserRepository.maxStoredRuns);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('전체 기록')),
      body: StreamBuilder<List<RunLog>>(
        stream: _runs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<RunLog> runs = snapshot.data ?? [];
          if (runs.isEmpty) return const _Empty();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Totals(runs: runs),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              for (final run in runs) ...[
                RunLogTile(
                  run: run,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RunDetailScreen(userId: widget.userId, run: run),
                    ),
                  ),
                ),
                if (run != runs.last) const Divider(),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                '기록은 최근 ${UserRepository.maxStoredRuns}개까지 보관합니다.',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.grey500),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 보관 중인 기록을 합친 값
class _Totals extends StatelessWidget {
  final List<RunLog> runs;

  const _Totals({required this.runs});

  @override
  Widget build(BuildContext context) {
    final double distance = runs.fold(0, (sum, r) => sum + r.distanceMeters);
    final int seconds = runs.fold(0, (sum, r) => sum + r.durationSeconds);
    final int gold = runs.fold(0, (sum, r) => sum + r.goldEarned);

    return Row(
      children: [
        _Total(value: '${runs.length}', label: '러닝'),
        _Total(value: formatKm(distance), label: '킬로미터'),
        _Total(value: formatHoursMinutes(seconds), label: '시간'),
        _Total(value: '$gold', label: '골드'),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  final String value;
  final String label;

  const _Total({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: textTheme.titleLarge),
          Text(label, style: textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          '아직 러닝 기록이 없어요.\n첫 러닝을 시작해 보세요.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.grey500),
        ),
      ),
    );
  }
}
