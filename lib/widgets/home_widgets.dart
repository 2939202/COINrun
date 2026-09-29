import 'package:flutter/material.dart';

import '../game/equipment_rules.dart';
import '../game/run_rules.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';
import '../services/ranking_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'notched_box.dart';
import 'segment_bar.dart';
import 'runner_figure.dart';

// ============================================================
// 홈 화면을 이루는 조각들
//
// 화면 파일(screens/main_screen.dart)에서 떼어냈습니다. 여기 있는 것들은 전부
// 값을 받아서 그리기만 하므로, 테스트에서 가짜 값으로 그려보고 눈으로 확인할 수 있습니다.
// ============================================================

// 인사 + 골드 + 설정
class HomeHeader extends StatelessWidget {
  final UserModel user;
  final VoidCallback onSettings;

  const HomeHeader({super.key, required this.user, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GOOD TO SEE YOU', style: AppTheme.caption),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user.nickname,
                style: textTheme.headlineMedium?.copyWith(fontSize: 28),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GoldPill(gold: user.gold),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: '설정',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

// 검은 레벨 카드. 모서리가 잘린 티켓 모양입니다.
class LevelCard extends StatelessWidget {
  final UserModel user;

  const LevelCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final int needed = RunRules.expToNextLevel(user.level);
    final double progress = (user.exp / needed).clamp(0.0, 1.0);

    return NotchedBox(
      cut: 16,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LEVEL',
                style: AppTheme.caption.copyWith(color: AppColors.accentOnDark),
              ),
              const Spacer(),
              // 등급표
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accentOnDark, width: 1.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  RunRules.tierName(user.level),
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.accentOnDark,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // 큰 레벨 숫자 + 오른쪽에 다음 레벨
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user.level}',
                style: AppTheme.number.copyWith(
                  fontSize: 64,
                  color: AppColors.white,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'NEXT',
                    style: AppTheme.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.accentOnDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Lv.${user.level + 1}',
                    style: AppTheme.number.copyWith(
                      fontSize: 26,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 큰 숫자와 경험치 글자 사이의 진행 바
          SegmentBar(
            progress: progress,
            filledColor: AppColors.accentOnDark,
            emptyColor: AppColors.trackOnDark,
            height: 9,
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${user.exp}',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontSize: 14,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        ' / $needed EXP',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.sand,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '다음 레벨까지 ${needed - user.exp}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.sand,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 누적 기록 세 칸. 위아래로 두 줄짜리 선이 지납니다.
class TotalsRow extends StatelessWidget {
  final UserModel user;

  const TotalsRow({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DoubleRule(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TotalBlock(
                    value: formatKm(user.totalDistance),
                    label: '총 킬로미터',
                  ),
                ),
                const VerticalDivider(color: AppColors.sand, width: 1),
                Expanded(
                  child: TotalBlock(
                    value: formatHoursMinutes(user.totalRunSeconds),
                    label: '총 시간',
                    padLeft: true,
                  ),
                ),
                const VerticalDivider(color: AppColors.sand, width: 1),
                Expanded(child: RankTotal(user: user)),
              ],
            ),
          ),
        ),
        const DoubleRule(),
      ],
    );
  }
}

class TotalBlock extends StatelessWidget {
  final String value;
  final String label;
  final bool padLeft;

  // 러닝 화면처럼 세 칸을 가운데 정렬로 쓸 때
  final bool center;

  const TotalBlock({
    super.key,
    required this.value,
    required this.label,
    this.padLeft = false,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(left: padLeft && !center ? AppSpacing.md : 0),
      child: Column(
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 숫자가 길어도 칸을 넘지 않게 줄여서 맞춥니다.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: center ? Alignment.center : Alignment.centerLeft,
            child: Text(value, style: AppTheme.number.copyWith(fontSize: 27)),
          ),
          const SizedBox(height: AppSpacing.xs + 1),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mute),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// 순위는 남들과 비교해야 알 수 있어서 유저 문서에는 없습니다.
// 화면에 들어올 때 한 번만 물어봅니다. (Firestore의 count 집계라 문서를 받아오지 않습니다)
class RankTotal extends StatefulWidget {
  final UserModel user;

  const RankTotal({super.key, required this.user});

  @override
  State<RankTotal> createState() => RankTotalState();
}

class RankTotalState extends State<RankTotal> {
  late final Future<int?> _rank = RankingRepository.instance.myRank(
    RankingKind.distance,
    widget.user,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _rank,
      builder: (context, snapshot) {
        final int? rank = snapshot.data;
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아직 순위가 없으면 줄 하나로 비워둡니다.
              if (rank == null)
                SizedBox(
                  height: 30,
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 2,
                      color: AppColors.black,
                    ),
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$rank위',
                    style: AppTheme.number.copyWith(fontSize: 30),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '거리 순위',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mute),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

// 굵은 줄 + 가는 줄
class DoubleRule extends StatelessWidget {
  const DoubleRule({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 2.4, color: AppColors.black),
        const SizedBox(height: 2.4),
        Container(height: 1, color: AppColors.black),
      ],
    );
  }
}

// 내 캐릭터 / 랭킹 두 장
class ShortcutsRow extends StatelessWidget {
  final UserModel user;
  final VoidCallback onCharacter;
  final VoidCallback onRanking;

  const ShortcutsRow({
    super.key,
    required this.user,
    required this.onCharacter,
    required this.onRanking,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: Row(
        children: [
          Expanded(
            child: RunnerCard(user: user, onTap: onCharacter),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: RankingCard(onTap: onRanking)),
        ],
      ),
    );
  }
}

class RunnerCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const RunnerCard({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          color: AppColors.cream,
          child: Stack(
            children: [
              // 캐릭터는 오른쪽 아래에 붙여서 얼굴만 나오게 잘립니다.
              Positioned(
                right: -18,
                bottom: -34,
                width: 118,
                height: 210,
                child: const RunnerFigure(showGround: false),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY RUNNER',
                      style: AppTheme.caption.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('내 캐릭터', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      EquipmentRules.equippedSetName(user),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RankingCard extends StatefulWidget {
  final VoidCallback onTap;

  const RankingCard({super.key, required this.onTap});

  @override
  State<RankingCard> createState() => RankingCardState();
}

class RankingCardState extends State<RankingCard> {
  late final Stream<List<RankingEntry>> _top = RankingRepository.instance
      .watchTop(RankingKind.distance, limit: 1);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.sand, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RANKING', style: AppTheme.caption.copyWith(fontSize: 11)),
            const SizedBox(height: AppSpacing.sm),
            Text('랭킹', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '전체 순위 보기',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.mute),
            ),
            const Spacer(),
            Container(height: 1, color: AppColors.sand),
            const SizedBox(height: AppSpacing.sm),

            // 1등만 살짝 보여줍니다.
            StreamBuilder<List<RankingEntry>>(
              stream: _top,
              builder: (context, snapshot) {
                final List<RankingEntry> top = snapshot.data ?? const [];
                if (top.isEmpty) {
                  return Text(
                    '아직 아무도 없어요',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.mute,
                    ),
                  );
                }
                final RankingEntry first = top.first;
                return Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent),
                      ),
                      child: Text(
                        '1',
                        style: AppTheme.number.copyWith(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        first.nickname,
                        style: textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatKm(first.totalDistance),
                      style: AppTheme.number.copyWith(fontSize: 17),
                    ),
                    Text(' km', style: textTheme.labelMedium),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GoldPill extends StatelessWidget {
  final int gold;

  const GoldPill({super.key, required this.gold});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cream,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.3),
            ),
            child: Text(
              'G',
              style: AppTheme.number.copyWith(
                fontSize: 9,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 1),
          Text('$gold', style: AppTheme.number.copyWith(fontSize: 14)),
          const SizedBox(width: 2),
          Text(
            'G',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.black,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
