import 'package:flutter/material.dart';

import '../game/week_plan.dart';
import '../services/week_coach.dart';
import '../theme/ai_palette.dart';
import '../theme/app_theme.dart';

// ============================================================
// 이번 주 목표 카드 (AI 평가 > 주간)
//
//   THIS WEEK                                  거리 늘리기
//   이번 주 목표
//   거리      4.0 / 12.6km   ━━━━━━━──────────
//   횟수      1 / 3회         ━━━━━━──────────
//   1회 최장  4.0 / 4.4km    ━━━━━━━━━━━━━━──
//   [AI 비서] 이유 문장
//   · 실행 방법
//   부하비 1.06 · 컨디션 -3 · 지난주 달성 105% · 5km 예상 30:12
//
// 숫자(목표 범위, 근거)는 폰에서 계산한 것이고, 이유와 실행 방법만 AI 비서가 씁니다.
// ============================================================
class WeekGoalCard extends StatelessWidget {
  final WeekPlanView view;

  const WeekGoalCard({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final WeekPlan plan = view.plan;
    final WeekFacts facts = view.facts;
    final WeekProgress done = facts.progress;
    final TextStyle body = AppTheme.sans.copyWith(
      fontSize: 13.5,
      height: 1.5,
      color: AppColors.black,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: AiPalette.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AiPalette.deep, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('THIS WEEK', style: AppTheme.caption.copyWith(fontSize: 11)),
              const Spacer(),
              _Tag(facts.goal.stage.label),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '이번 주 목표',
            style: AppTheme.serifNumber.copyWith(
              fontSize: 20,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _GoalRow(
            label: '거리',
            done: done.km,
            goal: plan.km,
            unit: 'km',
            decimals: 1,
          ),
          _GoalRow(
            label: '횟수',
            done: done.runs.toDouble(),
            goal: plan.runs.toDouble(),
            unit: '회',
            decimals: 0,
          ),
          _GoalRow(
            label: '1회 최장',
            done: done.longestKm,
            goal: plan.longestKm,
            unit: 'km',
            decimals: 1,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AiPalette.pale, height: 1),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            plan.writtenByAi ? 'AI 비서' : '기본 분석',
            style: AppTheme.sans.copyWith(
              fontSize: 11,
              fontWeight: AppTheme.sansMedium,
              color: AiPalette.mid,
            ),
          ),
          const SizedBox(height: 3),
          Text(plan.why, style: body),
          for (final line in plan.plan)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('·  ', style: body),
                  Expanded(child: Text(line, style: body)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm + 2),
          // 근거. 이 숫자들로 목표 범위를 정했습니다.
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs + 2,
            children: [
              for (final e in facts.evidence) _Evidence(e),
              _Evidence(
                Evidence(
                  '범위',
                  '${facts.goal.minKm.toStringAsFixed(1)}~'
                      '${facts.goal.maxKm.toStringAsFixed(1)}km',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 목표 한 줄: 이름, 진행/목표 숫자, 진행 막대
class _GoalRow extends StatelessWidget {
  final String label;
  final double done;
  final double goal;
  final String unit;
  final int decimals;

  const _GoalRow({
    required this.label,
    required this.done,
    required this.goal,
    required this.unit,
    required this.decimals,
  });

  @override
  Widget build(BuildContext context) {
    final double ratio = goal <= 0 ? 0 : (done / goal).clamp(0.0, 1.0);
    final bool reached = goal > 0 && done >= goal;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AppTheme.sans.copyWith(
                fontSize: 13,
                color: AppColors.label,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: done.toStringAsFixed(decimals),
                    style: AppTheme.number.copyWith(
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${goal.toStringAsFixed(decimals)}$unit',
                    style: AppTheme.sans.copyWith(
                      fontSize: 12,
                      color: AppColors.label,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AiPalette.pale),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratio,
                      child: ColoredBox(
                        color: reached ? AiPalette.deep : AiPalette.mid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AiPalette.deep,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: AppTheme.sans.copyWith(
          fontSize: 11,
          fontWeight: AppTheme.sansMedium,
          color: AiPalette.paper,
        ),
      ),
    );
  }
}

class _Evidence extends StatelessWidget {
  final Evidence evidence;

  const _Evidence(this.evidence);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AiPalette.pale),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${evidence.label} ',
              style: AppTheme.sans.copyWith(fontSize: 11, color: AiPalette.mid),
            ),
            TextSpan(
              text: evidence.value,
              style: AppTheme.sans.copyWith(
                fontSize: 11,
                fontWeight: AppTheme.sansMedium,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// AI 평가 주간 탭에서 쓰는, 불러오기까지 맡는 카드
class WeekGoalSection extends StatefulWidget {
  final String userId;

  const WeekGoalSection({super.key, required this.userId});

  @override
  State<WeekGoalSection> createState() => _WeekGoalSectionState();
}

class _WeekGoalSectionState extends State<WeekGoalSection> {
  late final Future<WeekPlanView> _plan = WeekCoach.instance.planFor(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeekPlanView>(
      future: _plan,
      builder: (context, snapshot) {
        final WeekPlanView? view = snapshot.data;
        if (view != null) return WeekGoalCard(view: view);
        return Container(
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AiPalette.paper,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            snapshot.hasError
                ? '이번 주 목표를 불러오지 못했습니다.'
                : 'AI 비서가 이번 주 목표를 정리하고 있습니다.',
            style: AppTheme.sans.copyWith(fontSize: 13, color: AppColors.label),
          ),
        );
      },
    );
  }
}
