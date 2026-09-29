import 'package:flutter/material.dart';

import '../game/stats_period.dart';
import '../models/run_stats.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

// ============================================================
// 홈 맨 위의 "이번 주" 블록
//
// 누적 총계(총 킬로미터, 총 시간) 자리를 대신합니다.
//
// 누적은 러닝 앱에서 동기가 가장 약한 숫자입니다. 3일 차에게 "누적 4km"는 의미가 없고,
// 3년 차에게 "누적 1,200km"는 이미 본 숫자입니다. 반면 이번 주는 누구에게나
// "지난주의 나"라는 항상 이길 수 있는 상대를 줍니다.
// ============================================================
class WeekSummary extends StatefulWidget {
  final String userId;

  const WeekSummary({super.key, required this.userId});

  @override
  State<WeekSummary> createState() => _WeekSummaryState();
}

class _WeekSummaryState extends State<WeekSummary> {
  // 최근 몇 주를 한 번에 받아옵니다. 이번 주/지난주 비교와 아래 막대에 같이 씁니다.
  static const int _weeks = 5;

  late final Stream<List<RunStats>> _stats = UserRepository.instance.watchStats(
    widget.userId,
    weekly: true,
    limit: _weeks,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RunStats>>(
      stream: _stats,
      builder: (context, snapshot) {
        final List<RunStats> weeks = snapshot.data ?? const [];

        // 뛰지 않은 주는 칸이 아예 없습니다. 날짜로 찾아야 빈 주를 0으로 볼 수 있습니다.
        final DateTime now = DateTime.now();
        final RunStats? thisWeek = _find(weeks, now);
        final RunStats? lastWeek = _find(
          weeks,
          now.subtract(const Duration(days: 7)),
        );

        return _Card(
          thisWeek: thisWeek,
          lastWeek: lastWeek,
          recent: [
            for (int back = _weeks - 1; back >= 0; back--)
              _find(
                    weeks,
                    now.subtract(Duration(days: 7 * back)),
                  )?.distanceKm ??
                  0,
          ],
        );
      },
    );
  }

  static RunStats? _find(List<RunStats> weeks, DateTime day) {
    final String key = StatsPeriod.weekKey(day);
    for (final week in weeks) {
      if (week.key == key) return week;
    }
    return null;
  }
}

class _Card extends StatelessWidget {
  final RunStats? thisWeek;
  final RunStats? lastWeek;
  final List<double> recent;

  const _Card({
    required this.thisWeek,
    required this.lastWeek,
    required this.recent,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final double km = thisWeek?.distanceKm ?? 0;
    final double lastKm = lastWeek?.distanceKm ?? 0;
    final int runs = thisWeek?.runs ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              _Compare(km: km, lastKm: lastKm),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                km.toStringAsFixed(2),
                style: textTheme.displayLarge?.copyWith(fontSize: 48),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('km', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Bars(values: recent),
          const SizedBox(height: AppSpacing.sm),
          Text(
            runs == 0
                ? '이번 주는 아직이에요'
                : '$runs번 · ${formatHoursMinutes(thisWeek?.seconds ?? 0)}',
            style: textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

// 지난주와의 차이
class _Compare extends StatelessWidget {
  final double km;
  final double lastKm;

  const _Compare({required this.km, required this.lastKm});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 지난주에 안 뛰었으면 비교할 것이 없습니다.
    if (lastKm <= 0) {
      return Text('지난주 기록 없음', style: textTheme.labelMedium);
    }

    final double diff = km - lastKm;
    final bool up = diff >= 0;
    return Row(
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: up ? AppColors.accent : AppColors.mute,
        ),
        const SizedBox(width: 2),
        Text(
          '${diff.abs().toStringAsFixed(1)} km',
          style: textTheme.labelMedium?.copyWith(
            color: up ? AppColors.accent : AppColors.mute,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// 최근 몇 주를 작은 막대로. 오른쪽 끝이 이번 주입니다.
class _Bars extends StatelessWidget {
  final List<double> values;

  const _Bars({required this.values});

  @override
  Widget build(BuildContext context) {
    final double top = values.fold<double>(0, (a, b) => b > a ? b : a);

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Container(
                // 0인 주도 자리를 보여줘야 "안 뛴 주"가 눈에 들어옵니다.
                height: top <= 0 ? 3 : (3 + 33 * (values[i] / top)),
                decoration: BoxDecoration(
                  color: i == values.length - 1
                      ? AppColors.black
                      : AppColors.sand,
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
