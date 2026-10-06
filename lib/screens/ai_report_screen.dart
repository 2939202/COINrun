import 'package:flutter/material.dart';

import '../game/run_calendar.dart';
import '../game/run_insights.dart';
import '../models/run_log.dart';
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
//   검은 카드(점수, 점수 내역, 이번 달 달력) -> AI 비서의 말풍선(한 줄 평 + 조언)
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

  // 달력에 그릴 이번 달 기록 (앞뒤 주의 칸까지)
  late final Stream<List<RunLog>> _monthRuns = () {
    final (DateTime start, DateTime end) = RunCalendar.rangeOf(DateTime.now());
    return UserRepository.instance.watchRunsBetween(widget.userId, start, end);
  }();

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
            // 검은 카드가 맨 위. 달력은 기록이 오기 전에도 빈 칸으로 먼저 그립니다.
            StreamBuilder<List<RunLog>>(
              stream: _monthRuns,
              builder: (context, runs) => InsightScoreCard(
                report: report,
                calendar: RunCalendar.of(DateTime.now(), runs.data ?? const []),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // 그 아래 AI 비서의 말풍선
            AiAdvisorSection(report: report),
            const SizedBox(height: AppSpacing.xl),
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
class InsightScoreCard extends StatelessWidget {
  final InsightReport report;
  final RunCalendar calendar;

  const InsightScoreCard({
    super.key,
    required this.report,
    required this.calendar,
  });

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
          const SizedBox(height: AppSpacing.lg),
          _FoldableCalendar(calendar: calendar, weekOnly: report.range.isWeek),
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

// 달력 접기/펴기. 처음에는 접혀 있어서 점수만 한눈에 보입니다.
// 탭을 오가도 펼친 상태가 남습니다. (탭이 살아 있는 동안)
class _FoldableCalendar extends StatefulWidget {
  final RunCalendar calendar;
  final bool weekOnly;

  const _FoldableCalendar({required this.calendar, required this.weekOnly});

  @override
  State<_FoldableCalendar> createState() => _FoldableCalendarState();
}

class _FoldableCalendarState extends State<_FoldableCalendar> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final DateTime today = widget.calendar.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 누르는 줄. 높이를 넉넉히 둬서 손가락으로 누르기 쉽게 합니다.
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  '${today.year}.${today.month.toString().padLeft(2, '0')} 달력',
                  style: AppTheme.caption.copyWith(color: AppColors.sandOnDark),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppColors.sandOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _CalendarGrid(
                    calendar: widget.calendar,
                    weekOnly: widget.weekOnly,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// 검은 카드 안의 이번 달 달력. 칸마다 그날 달린 거리를 숫자와 게이지로 보여줍니다.
// 이번 기간(주간 탭은 이번 주, 월간 탭은 이번 달)은 흰 바탕으로 밝게 칠합니다.
class _CalendarGrid extends StatelessWidget {
  final RunCalendar calendar;
  final bool weekOnly;

  const _CalendarGrid({required this.calendar, required this.weekOnly});

  static const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final DateTime today = calendar.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final name in _weekdays)
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppTheme.sans.copyWith(
                    fontSize: 10,
                    color: AppColors.sandOnDark.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final row in calendar.rows)
          Row(
            children: [
              for (final day in row)
                Expanded(
                  child: _DayCell(
                    day: day,
                    km: calendar.kmOn(day),
                    fullKm: calendar.gaugeFullKm,
                    bright: weekOnly
                        ? calendar.isThisWeek(day)
                        : calendar.isThisMonth(day),
                    otherMonth: !calendar.isThisMonth(day),
                    future: calendar.isFuture(day),
                    today: day == today,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// 달력 한 칸: 왼쪽 위 날짜, 가운데 km, 아래 게이지
class _DayCell extends StatelessWidget {
  final DateTime day;
  final double km;
  final double fullKm;
  final bool bright; // 이번 기간 - 흰 바탕
  final bool otherMonth; // 앞뒤 달의 날짜 - 흐리게
  final bool future; // 아직 오지 않은 날 - 숫자와 게이지 없음
  final bool today;

  const _DayCell({
    required this.day,
    required this.km,
    required this.fullKm,
    required this.bright,
    required this.otherMonth,
    required this.future,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final Color ink = bright ? AppColors.black : AppColors.sandOnDark;
    final Color fill = bright ? AppColors.accent : AppColors.accentOnDark;
    final Color track = bright ? AppColors.sand : AppColors.trackOnDark;
    final bool ran = km > 0 && !future;

    return Opacity(
      opacity: otherMonth && !bright ? 0.35 : 1,
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 4),
        decoration: BoxDecoration(
          color: bright ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          // 오늘: 흰 칸에서는 검은 테두리, 검은 칸에서는 금빛 테두리
          border: today
              ? Border.all(
                  color: bright ? AppColors.black : AppColors.accentOnDark,
                  width: 1.6,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: AppTheme.sans.copyWith(
                fontSize: 9,
                height: 1.1,
                color: ink.withValues(alpha: future ? 0.5 : 0.8),
              ),
            ),
            Expanded(
              child: Center(
                child: ran
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          km.toStringAsFixed(1),
                          style: AppTheme.number.copyWith(
                            fontSize: 12,
                            color: ink,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            // 그날 거리 게이지. 이 달 가장 많이 뛴 날이 가득입니다.
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: future ? Colors.transparent : track),
                    if (ran)
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (km / fullKm).clamp(0.08, 1.0),
                        child: ColoredBox(color: fill),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
