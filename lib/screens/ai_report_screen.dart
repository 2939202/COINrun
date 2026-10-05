import 'package:flutter/material.dart';

import '../game/run_insights.dart';
import '../models/run_stats.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/notched_box.dart';
import '../widgets/segment_bar.dart';
import '../utils/formatters.dart';

// ============================================================
// AI 평가 화면
//
// 주간 / 월간 탭. 탭마다
//   점수와 등급 -> 점수 내역(꾸준함·운동량·흐름) -> 이번과 지난번 비교
//   -> 최근 6주(6달) 거리 막대 -> 조언
// 계산은 game/run_insights.dart가 합니다. 이 화면은 그리기만 합니다.
// ============================================================
class AiReportScreen extends StatelessWidget {
  final String userId;

  const AiReportScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: InsightRange.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI 평가'),
          bottom: TabBar(
            indicatorColor: AppColors.black,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.black,
            unselectedLabelColor: AppColors.mute,
            labelStyle: const TextStyle(
              fontFamily: AppTheme.hangulSerifFont,
              fontSize: 17,
              fontWeight: AppTheme.serifWeight,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: AppTheme.sansFont,
              fontSize: 17,
              fontWeight: AppTheme.sansMedium,
            ),
            dividerColor: AppColors.sand,
            tabs: [
              for (final range in InsightRange.values) Tab(text: range.label),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final range in InsightRange.values)
              _InsightTab(userId: userId, range: range),
          ],
        ),
      ),
    );
  }
}

// 홈 카드와 화면이 같은 계산을 쓰도록 스트림을 만드는 곳을 하나로 둡니다.
Stream<InsightReport> watchInsight(String userId, InsightRange range) {
  final DateTime now = DateTime.now();
  return UserRepository.instance
      .watchStatsByKeys(userId, RunInsights.keysFor(range, now))
      .map(
        (Map<String, RunStats> stats) => RunInsights.analyze(
          range: range,
          statsByKey: stats,
          now: DateTime.now(),
        ),
      );
}

class _InsightTab extends StatefulWidget {
  final String userId;
  final InsightRange range;

  const _InsightTab({required this.userId, required this.range});

  @override
  State<_InsightTab> createState() => _InsightTabState();
}

class _InsightTabState extends State<_InsightTab>
    with AutomaticKeepAliveClientMixin {
  late final Stream<InsightReport> _report = watchInsight(
    widget.userId,
    widget.range,
  );

  // 탭을 오갈 때마다 다시 읽지 않게 붙잡아 둡니다.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<InsightReport>(
      stream: _report,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('기록을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.'));
        }
        final InsightReport? report = snapshot.data;
        if (report == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ScoreCard(report: report),
            const SizedBox(height: AppSpacing.lg),
            _CompareRow(report: report),
            const SizedBox(height: AppSpacing.xl),
            _DistanceBars(report: report),
            const SizedBox(height: AppSpacing.xl),
            Text('조언', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            for (final comment in report.comments) _CommentTile(comment),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '기록은 폰 안에서만 분석해요. 밖으로 보내지 않아요.',
              style: Theme.of(context).textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

// 검은 점수 카드: 등급 글자 + 점수 + 한 줄 평 + 점수 내역
class _ScoreCard extends StatelessWidget {
  final InsightReport report;

  const _ScoreCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final TextStyle small = AppTheme.sans.copyWith(
      color: AppColors.sandOnDark,
      fontSize: 13,
    );

    return NotchedBox(
      cut: 16,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.range.label.toUpperCase()} REPORT',
            style: AppTheme.caption.copyWith(color: AppColors.sandOnDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 등급(S~D)은 두지 않습니다. 점수만 보여줍니다.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${report.score}',
                  style: AppTheme.serifNumber.copyWith(
                    fontSize: 56,
                    color: AppColors.accentOnDark,
                  ),
                ),
                TextSpan(text: '  / 100', style: small),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            report.headline,
            style: AppTheme.serifNumber.copyWith(
              fontSize: 19,
              color: AppColors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _part('꾸준함', report.consistencyScore, 40, small),
          const SizedBox(height: AppSpacing.sm + 2),
          _part('운동량', report.volumeScore, 30, small),
          const SizedBox(height: AppSpacing.sm + 2),
          _part('흐름', report.trendScore, 30, small),
        ],
      ),
    );
  }

  Widget _part(String label, int value, int max, TextStyle style) {
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label, style: style)),
        Expanded(
          child: SegmentBar(
            progress: value / max,
            filledColor: AppColors.accentOnDark,
            emptyColor: AppColors.trackOnDark,
            height: 8,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$value / $max',
            style: style,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// 이번 vs 지난번: 거리, 횟수, 페이스
class _CompareRow extends StatelessWidget {
  final InsightReport report;

  const _CompareRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final PeriodSummary now = report.current;
    final PeriodSummary before = report.previous;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${report.range.current} vs ${report.range.previous}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            if (report.progress < 1)
              Text(
                '${(report.progress * 100).round()}% 지남',
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(height: 1, color: AppColors.black),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cell(
                '거리 km',
                now.km.toStringAsFixed(1),
                before.km.toStringAsFixed(1),
              ),
              const VerticalDivider(color: AppColors.sand, width: 1),
              _cell('러닝 횟수', '${now.runs}', '${before.runs}'),
              const VerticalDivider(color: AppColors.sand, width: 1),
              _cell(
                '평균 페이스',
                formatPace(now.paceMinPerKm),
                formatPace(before.paceMinPerKm),
              ),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.sand),
      ],
    );
  }

  Widget _cell(String label, String now, String before) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                now,
                style: AppTheme.serifNumber.copyWith(
                  fontSize: 26,
                  color: AppColors.black,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '지난 $before',
              style: AppTheme.sans.copyWith(
                fontSize: 12,
                color: AppColors.mute,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.sans.copyWith(
                fontSize: 13,
                color: AppColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 최근 6주(6달) 거리 막대. 이번 주(달)는 진한 색, 진행 중이면 예상치를 옅게 겹칩니다.
class _DistanceBars extends StatelessWidget {
  final InsightReport report;

  const _DistanceBars({required this.report});

  static const double _height = 120;

  String _label(DateTime start) =>
      report.range.isWeek ? '${start.month}/${start.day}' : '${start.month}월';

  @override
  Widget build(BuildContext context) {
    final List<PeriodSummary> periods = report.periods;
    final double projected = report.projectedKm;
    final double top = [
      ...periods.map((period) => period.km),
      projected,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 ${periods.length}${report.range.unit} 거리',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: _height + 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < periods.length; i++)
                Expanded(
                  child: _bar(
                    periods[i],
                    isCurrent: i == periods.length - 1,
                    projected: projected,
                    top: top,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(
    PeriodSummary period, {
    required bool isCurrent,
    required double projected,
    required double top,
  }) {
    final double barHeight = _height * period.km / top;
    final double ghostHeight = isCurrent && report.progress < 1
        ? _height * projected / top
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            period.km.toStringAsFixed(1),
            style: AppTheme.serifNumber.copyWith(
              fontSize: 12,
              color: isCurrent ? AppColors.black : AppColors.mute,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: _height,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 예상치 (점선 대신 옅은 막대)
                if (ghostHeight > barHeight)
                  Container(
                    height: ghostHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent, width: 1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                Container(
                  height: barHeight.clamp(2, _height),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.accent : AppColors.sand,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isCurrent ? report.range.current : _label(period.start),
            style: AppTheme.sans.copyWith(
              fontSize: 11,
              color: isCurrent ? AppColors.black : AppColors.label,
              fontWeight: isCurrent
                  ? AppTheme.sansMedium
                  : AppTheme.sansRegular,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final InsightComment comment;

  const _CommentTile(this.comment);

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (comment.tone) {
      InsightTone.good => (Icons.trending_up, AppColors.accent),
      InsightTone.warn => (Icons.error_outline, AppColors.error),
      InsightTone.info => (Icons.lightbulb_outline, AppColors.mute),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              comment.text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
