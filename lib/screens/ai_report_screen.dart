import 'package:flutter/material.dart';

import '../game/run_insights.dart';
import '../models/run_stats.dart';
import '../services/ai_coach.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/notched_box.dart';
import '../widgets/segment_bar.dart';
import '../utils/formatters.dart';

// ============================================================
// AI 평가 화면
//
// 주간 / 월간 탭. 탭마다
//   AI 비서의 말풍선(한 줄 평 + 조언) -> 점수와 점수 내역(꾸준함·운동량·흐름)
//   -> 이번과 지난번 비교 -> 최근 6주(6달) 거리 막대
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
//
// 먼저 규칙 문장으로 된 보고서를 바로 내보내고, AI 비서의 문장이 도착하면
// 문장만 바꾼 보고서를 한 번 더 내보냅니다. 그래서 기다리는 동안 화면이 비지 않습니다.
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
      )
      .asyncExpand((report) async* {
        yield report;
        final AiWords? words = await AiCoach.instance.wordsFor(userId, report);
        if (words != null) {
          yield report.withWords(
            headline: words.headline,
            comments: words.comments,
          );
        } else if (report.hasAnyRun) {
          // 실패했으면 같은 보고서를 한 번 더 보내서, 화면이 실패 이유를 그리게 합니다.
          yield report;
        }
      });
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
          return const Center(child: Text('기록을 불러오지 못했습니다. 인터넷 연결을 확인해 주십시오.'));
        }
        final InsightReport? report = snapshot.data;
        if (report == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // AI 평가는 맨 위. 비서가 말하듯 말풍선으로 보여줍니다.
            AiAdvisorSection(report: report),
            const SizedBox(height: AppSpacing.xl),
            _ScoreCard(report: report),
            const SizedBox(height: AppSpacing.lg),
            _CompareRow(report: report),
            const SizedBox(height: AppSpacing.xl),
            _DistanceBars(report: report),
            const SizedBox(height: AppSpacing.xl),
            Text(
              '점수는 폰에서 계산합니다. 문장은 AI 비서(Gemini)가 숫자만 받아 작성하며, '
              '경로와 이름은 보내지 않습니다.',
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

// AI 비서 영역: 왼쪽에 "AI" 표시, 오른쪽에 말풍선이 차례로 쌓입니다.
//   첫 말풍선(검정) - 한 줄 평
//   다음 말풍선(크림) - 조언. 앞에 작은 표시로 잘한 점 / 주의 / 참고를 나눕니다.
class AiAdvisorSection extends StatelessWidget {
  final InsightReport report;

  const AiAdvisorSection({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? error = AiCoach.instance.lastError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('AI 평가', style: textTheme.titleLarge),
            const Spacer(),
            Text(
              report.writtenByAi ? 'AI 비서 작성' : '기본 분석',
              style: textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AdvisorBadge(),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bubble(
                    dark: true,
                    child: Text(
                      report.headline,
                      style: AppTheme.serifNumber.copyWith(
                        fontSize: 16,
                        height: 1.4,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  for (final comment in report.comments)
                    _Bubble(child: _CommentLine(comment)),
                ],
              ),
            ),
          ],
        ),
        // AI 문장을 못 받았으면 이유를 작게 보여줍니다. (원인을 폰에서 바로 확인)
        if (!report.writtenByAi && report.hasAnyRun && error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'AI 연결 실패: $error',
            style: textTheme.labelMedium?.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

// 말풍선 왼쪽의 "AI" 표시
class _AdvisorBadge extends StatelessWidget {
  const _AdvisorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.black,
        shape: BoxShape.circle,
      ),
      child: Text(
        'AI',
        style: AppTheme.sans.copyWith(
          fontSize: 12,
          fontWeight: AppTheme.sansMedium,
          color: AppColors.sandOnDark,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// 말풍선. 왼쪽 위 모서리만 덜 둥글게 해서 "AI" 쪽에서 나온 말처럼 보이게 합니다.
class _Bubble extends StatelessWidget {
  final Widget child;
  final bool dark;

  const _Bubble({required this.child, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: AppSpacing.sm + 3,
        ),
        decoration: BoxDecoration(
          color: dark ? AppColors.black : AppColors.cream,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(AppRadius.md),
          ),
        ),
        child: child,
      ),
    );
  }
}

// 조언 한 줄: 앞에 작은 표시(잘한 점 / 주의 / 참고) + 문장
class _CommentLine extends StatelessWidget {
  final InsightComment comment;

  const _CommentLine(this.comment);

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (comment.tone) {
      InsightTone.good => ('잘한 점', AppColors.accent),
      InsightTone.warn => ('주의', AppColors.error),
      InsightTone.info => ('참고', AppColors.label),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.sans.copyWith(
            fontSize: 11,
            fontWeight: AppTheme.sansMedium,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          comment.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
