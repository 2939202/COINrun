import 'package:flutter/material.dart';

import '../game/run_calendar.dart';
import '../game/run_insights.dart';
import '../models/run_log.dart';
import '../models/run_stats.dart';
import '../services/ai_coach.dart';
import '../services/user_repository.dart';
import '../theme/ai_palette.dart';
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
        // 달력은 기록이 오기 전에도 빈 칸으로 먼저 그립니다.
        return StreamBuilder<List<RunLog>>(
          stream: _monthRuns,
          builder: (context, runs) => InsightTabBody(
            userId: widget.userId,
            report: report,
            calendar: RunCalendar.of(DateTime.now(), runs.data ?? const []),
          ),
        );
      },
    );
  }
}

// 탭 한 장의 내용. 위에서부터 리포트 카드 -> AI 비서 말풍선 -> 지난번과 비교
// -> 최근 거리 막대. 불러오기와 떼어 두어 그대로 그려볼 수 있습니다.
class InsightTabBody extends StatelessWidget {
  final String userId;
  final InsightReport report;
  final RunCalendar calendar;

  const InsightTabBody({
    super.key,
    required this.userId,
    required this.report,
    required this.calendar,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        InsightScoreCard(report: report, calendar: calendar),
        const SizedBox(height: AppSpacing.xl),
        AiAdvisorSection(userId: userId, report: report),
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
      color: _ReportInk.muted,
      fontSize: 11,
    );

    // 한 줄에 점수(왼쪽)와 점수 내역(오른쪽)을 나란히 둬서 높이를 줄입니다.
    // 색은 짙은 먹색 바탕에 놋쇠색 점수, 안쪽에 놋쇠색 실선을 한 줄 둘러 고급스럽게.
    return NotchedBox(
      cut: 12,
      color: _ReportInk.card,
      innerBorderColor: _ReportInk.line,
      innerBorderInset: 4,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 4,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${report.range.label.toUpperCase()} REPORT',
                    style: AppTheme.caption.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: _ReportInk.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${report.score}',
                          style: AppTheme.serifNumber.copyWith(
                            fontSize: 34,
                            color: _ReportInk.accent,
                          ),
                        ),
                        TextSpan(text: ' / 100', style: small),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  children: [
                    _part('꾸준함', report.consistencyScore, 40, small),
                    const SizedBox(height: 5),
                    _part('운동량', report.volumeScore, 30, small),
                    const SizedBox(height: 5),
                    _part('흐름', report.trendScore, 30, small),
                  ],
                ),
              ),
            ],
          ),
          _FoldableCalendar(calendar: calendar, weekOnly: report.range.isWeek),
        ],
      ),
    );
  }

  Widget _part(String label, int value, int max, TextStyle style) {
    return Row(
      children: [
        SizedBox(width: 38, child: Text(label, style: style)),
        Expanded(
          child: SegmentBar(
            progress: value / max,
            filledColor: _ReportInk.accent,
            emptyColor: _ReportInk.track,
            height: 5,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('$value/$max', style: style, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

// 리포트 카드의 색. 예전 갈색 바탕이 탁해 보여서 짙은 먹색 + 놋쇠색으로 바꿨습니다.
// 홈의 검은 카드, 플레이어 카드와 같은 계열입니다.
class _ReportInk {
  _ReportInk._();

  static const Color card = Color(0xFF221D19); // 바탕 (따뜻한 먹색)
  static const Color text = AppColors.paperOnDark; // 글자
  static const Color accent = AppColors.accentOnDark; // 점수, 채운 막대 (놋쇠색)
  static const Color line = Color(0x66C9A87C); // 안쪽 실선 (놋쇠색 40%)
  static const Color muted = Color(0xB3ECDDBE); // 종이색 70% - 작은 글자
  static const Color track = Color(0x33ECDDBE); // 종이색 20% - 막대 바닥
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
        Container(height: 1, color: AiPalette.ink),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cell(
                '거리 km',
                now.km.toStringAsFixed(1),
                before.km.toStringAsFixed(1),
                change: _Change.of(
                  now.km - before.km,
                  text: '${(now.km - before.km).abs().toStringAsFixed(1)}km',
                ),
              ),
              const VerticalDivider(color: AiPalette.pale, width: 1),
              _cell(
                '러닝 횟수',
                '${now.runs}',
                '${before.runs}',
                change: _Change.of(
                  (now.runs - before.runs).toDouble(),
                  text: '${(now.runs - before.runs).abs()}회',
                ),
              ),
              const VerticalDivider(color: AiPalette.pale, width: 1),
              _cell(
                '평균 페이스',
                formatPace(now.paceMinPerKm),
                formatPace(before.paceMinPerKm),
                // 페이스는 숫자가 작을수록(빠를수록) 좋아진 것입니다.
                change: now.paceMinPerKm == null || before.paceMinPerKm == null
                    ? null
                    : _Change.of(
                        before.paceMinPerKm! - now.paceMinPerKm!,
                        text:
                            '${((before.paceMinPerKm! - now.paceMinPerKm!).abs() * 60).round()}초',
                      ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: AiPalette.pale),
      ],
    );
  }

  Widget _cell(String label, String now, String before, {_Change? change}) {
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
                  color: AiPalette.ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (change != null) ...[
              change,
              const SizedBox(height: AppSpacing.xs),
            ],
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
              color: isCurrent ? AiPalette.ink : AiPalette.mid,
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
                      border: Border.all(color: AiPalette.mid, width: 1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                Container(
                  height: barHeight.clamp(2, _height),
                  decoration: BoxDecoration(
                    color: isCurrent ? AiPalette.deep : AiPalette.pale,
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
            child: Row(
              children: [
                Text(
                  '${today.year}.${today.month.toString().padLeft(2, '0')} 달력',
                  style: AppTheme.caption.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: _ReportInk.muted,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: _ReportInk.muted,
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
                    color: _ReportInk.muted,
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
    // 리포트 카드가 밝은 갈색이라, 이번 기간은 먹색 칸으로 뒤집어 칠합니다.
    final Color ink = bright ? AiPalette.ink : _ReportInk.text;
    final Color fill = bright ? AiPalette.deep : _ReportInk.accent;
    final Color track = bright ? AiPalette.pale : _ReportInk.track;
    final bool ran = km > 0 && !future;

    return Opacity(
      opacity: otherMonth && !bright ? 0.35 : 1,
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 4),
        decoration: BoxDecoration(
          color: bright ? AiPalette.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          // 오늘: 흰 칸에서는 검은 테두리, 검은 칸에서는 금빛 테두리
          border: today
              ? Border.all(
                  color: bright ? AiPalette.deep : _ReportInk.accent,
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
//
//   (AI)  [한 줄 평]                       <- 늘 보입니다
//         더보기 ▾                         <- 처음엔 접혀 있습니다
//         [▼ 아쉬운 점 ...]
//                          [알겠습니다.]   <- 내 답장 (오른쪽)
//         [▲ 잘한 점 ...]
//                           [고마워요!]
//
// 평가가 새로 나왔을 때만 하나씩 보여주고 답장을 받습니다. 끝까지 답하면 기억해 두고,
// 다음부터 같은 평가는 답장 없이 한꺼번에 보여줍니다. (AiCoach.repliedKey)
class AiAdvisorSection extends StatefulWidget {
  final String userId;
  final InsightReport report;

  const AiAdvisorSection({
    super.key,
    required this.userId,
    required this.report,
  });

  @override
  State<AiAdvisorSection> createState() => _AiAdvisorSectionState();
}

class _AiAdvisorSectionState extends State<AiAdvisorSection> {
  bool _open = false;

  // 이 평가에 이미 끝까지 답했는지. 읽는 중이면 null (그동안은 답한 것으로 봅니다)
  bool? _replied;
  final List<String> _answers = [];
  late String _key = AiCoach.replyKey(widget.report);

  @override
  void initState() {
    super.initState();
    _loadReplied();
  }

  @override
  void didUpdateWidget(AiAdvisorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String key = AiCoach.replyKey(widget.report);
    if (key == _key) return;
    // 평가가 바뀌었으면(규칙 문장 -> AI 문장 등) 대화를 처음부터 다시 합니다.
    _key = key;
    _answers.clear();
    _replied = null;
    _loadReplied();
  }

  Future<void> _loadReplied() async {
    final String key = _key;
    final bool replied = await AiCoach.instance.wasReplied(
      widget.userId,
      widget.report.range,
      key,
    );
    if (mounted && key == _key) setState(() => _replied = replied);
  }

  static String _answerFor(InsightTone tone) =>
      tone == InsightTone.good ? '고마워요!' : '알겠습니다.';

  void _answer(String text) {
    setState(() => _answers.add(text));
    if (_answers.length >= widget.report.comments.length) {
      AiCoach.instance.markReplied(widget.userId, widget.report.range, _key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? error = AiCoach.instance.lastError;
    final InsightReport report = widget.report;
    final List<InsightComment> comments = report.comments;
    // 새 평가면 하나씩, 이미 답한 평가면 한꺼번에
    final bool talking = _replied == false;
    final int shown = talking
        ? (_answers.length + 1).clamp(0, comments.length)
        : comments.length;

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
                    fill: AiPalette.ink,
                    child: Text(
                      report.headline,
                      style: AppTheme.serifNumber.copyWith(
                        fontSize: 16,
                        height: 1.4,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  if (comments.isNotEmpty)
                    _FoldButton(
                      open: _open,
                      count: comments.length,
                      onTap: () => setState(() => _open = !_open),
                    ),
                  if (_open)
                    for (int i = 0; i < shown; i++) ...[
                      _Bubble.forTone(
                        comments[i].tone,
                        child: _CommentLine(comments[i]),
                      ),
                      if (talking && i < _answers.length)
                        _MyBubble(text: _answers[i])
                      else if (talking && i == _answers.length)
                        _ReplyButton(
                          text: _answerFor(comments[i].tone),
                          onTap: () => _answer(_answerFor(comments[i].tone)),
                        ),
                    ],
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

// 한 줄 평 아래 "더보기 ▾ / 접기 ▴"
class _FoldButton extends StatelessWidget {
  final bool open;
  final int count;
  final VoidCallback onTap;

  const _FoldButton({
    required this.open,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xs,
          bottom: AppSpacing.sm,
        ),
        // 눈에 띄게: 진한 갈색 알약 버튼 (펼친 뒤 "접기"는 옅게)
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: open ? AiPalette.pale : AiPalette.deep,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AiPalette.soft),
            ),
            child: Text(
              open ? '접기 ▴' : '더보기 ▾  조언 $count개',
              style: AppTheme.sans.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: open ? AiPalette.deep : AiPalette.paper,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 내 답장 말풍선 (오른쪽, 오른쪽 위 모서리만 덜 둥글게)
class _MyBubble extends StatelessWidget {
  final String text;

  const _MyBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 64, bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AiPalette.soft),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.md),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          text,
          style: AppTheme.sans.copyWith(fontSize: 13.5, color: AiPalette.ink),
        ),
      ),
    );
  }
}

// 답장 버튼. 누르면 내 말풍선이 되고 다음 조언이 나옵니다.
class _ReplyButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _ReplyButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AiPalette.ink,
            side: const BorderSide(color: AiPalette.ink, width: 1.2),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            minimumSize: const Size(0, 34),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}

// 말풍선 왼쪽의 "AI" 표시
// AI 비서 얼굴: 헤드폰 쓴 픽셀 로봇 (assets/icons/ai_advisor.png)
class _AdvisorBadge extends StatelessWidget {
  const _AdvisorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.fromLTRB(3, 4, 3, 0),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.sand),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icons/ai_advisor.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}

// 말풍선. 왼쪽 위 모서리만 덜 둥글게 해서 "AI" 쪽에서 나온 말처럼 보이게 합니다.
// 조언은 뜻에 따라 명암이 다릅니다. (theme/ai_palette.dart)
class _Bubble extends StatelessWidget {
  final Widget child;
  final Color fill;
  final Color? border;

  const _Bubble({required this.child, required this.fill, this.border});

  factory _Bubble.forTone(InsightTone tone, {required Widget child}) =>
      switch (tone) {
        InsightTone.good => _Bubble(fill: AiPalette.goodFill, child: child),
        InsightTone.warn => _Bubble(fill: AiPalette.badFill, child: child),
        InsightTone.info => _Bubble(
          fill: AiPalette.paper,
          border: AiPalette.pale,
          child: child,
        ),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 40, bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: AppSpacing.sm + 3,
        ),
        decoration: BoxDecoration(
          color: fill,
          border: border == null ? null : Border.all(color: border!),
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

// 조언 한 줄: 위에 ▲ 잘한 점 / ▼ 아쉬운 점 / · 참고, 아래에 문장
class _CommentLine extends StatelessWidget {
  final InsightComment comment;

  const _CommentLine(this.comment);

  @override
  Widget build(BuildContext context) {
    final (String label, Color text, Color tag) = switch (comment.tone) {
      InsightTone.good => ('▲ 잘한 점', AiPalette.goodText, AiPalette.soft),
      InsightTone.warn => ('▼ 아쉬운 점', AiPalette.badText, AiPalette.deep),
      InsightTone.info => ('· 참고', AiPalette.ink, AiPalette.mid),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.sans.copyWith(
            fontSize: 11,
            fontWeight: AppTheme.sansMedium,
            color: tag,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          comment.text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(height: 1.5, color: text),
        ),
      ],
    );
  }
}

// 비교 줄의 변화 표시. 좋아졌으면 짙은 칩(▲), 나빠졌으면 밝은 칩(▼), 같으면 없음.
class _Change extends StatelessWidget {
  final bool better;
  final String text;

  const _Change({required this.better, required this.text});

  static _Change? of(double delta, {required String text}) {
    if (delta.abs() < 1e-9) return null;
    return _Change(better: delta > 0, text: text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: better ? AiPalette.goodFill : AiPalette.badFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '${better ? '▲' : '▼'} $text',
        style: AppTheme.sans.copyWith(
          fontSize: 11,
          fontWeight: AppTheme.sansMedium,
          color: better ? AiPalette.goodText : AiPalette.badText,
        ),
      ),
    );
  }
}
