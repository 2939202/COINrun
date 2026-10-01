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

  // 인사말-이름, 이름-레벨 카드 사이 간격
  static const double nameGap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GOOD TO SEE YOU',
                style: AppTheme.caption.copyWith(
                  fontFamily: AppTheme.sansFont,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentDeep,
                  // 자연산스는 Medium(500)이 가장 굵습니다. 그보다 진하게 보이도록
                  // 같은 색 그림자를 옆으로 살짝 겹칩니다.
                  shadows: const [
                    Shadow(color: AppColors.accentDeep, offset: Offset(0.4, 0)),
                  ],
                ),
              ),
              // 이름은 인사말과 레벨 카드 사이 한가운데에 옵니다.
              // (아래 간격은 main_screen.dart에서 같은 값으로 맞춥니다)
              const SizedBox(height: HomeHeader.nameGap),
              Text(
                user.nickname,
                style: AppTheme.serifNumber.copyWith(
                  fontSize: 34,
                  color: AppColors.black,
                ),
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
          color: AppColors.black,
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
    final int needed = RunRules.expToNextLevel(user.level);
    final double progress = (user.exp / needed).clamp(0.0, 1.0);

    return NotchedBox(
      cut: 16,
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
                style: AppTheme.caption.copyWith(
                  fontFamily: AppTheme.sansFont,
                  fontWeight: FontWeight.w400,
                  color: AppColors.sandOnDark,
                ),
              ),
              const Spacer(),
              // 등급표
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.sandOnDark, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  RunRules.tierName(user.level),
                  style: AppTheme.sans.copyWith(
                    color: AppColors.paperOnDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // 큰 레벨 숫자 + 오른쪽에 다음 레벨
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${user.level}',
                style: AppTheme.serifNumber.copyWith(
                  fontSize: 76,
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
                      fontFamily: AppTheme.sansFont,
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                      color: AppColors.sandOnDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Lv.${user.level + 1}',
                    style: AppTheme.serifNumber.copyWith(
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
                      style: AppTheme.sans.copyWith(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        ' / $needed EXP',
                        style: AppTheme.sans.copyWith(
                          color: AppColors.sandOnDark,
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
                  style: AppTheme.sans.copyWith(
                    color: AppColors.sandOnDark,
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
        // 위는 두 줄, 아래는 한 줄. 세 줄 모두 같은 굵기입니다.
        const DoubleRule(thick: 1),
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
                    home: true,
                  ),
                ),
                const VerticalDivider(color: AppColors.sand, width: 1),
                Expanded(
                  child: TotalBlock(
                    value: formatHoursMinutes(user.totalRunSeconds),
                    label: '총 시간',
                    padLeft: true,
                    home: true,
                  ),
                ),
                const VerticalDivider(color: AppColors.sand, width: 1),
                Expanded(child: RankTotal(user: user)),
              ],
            ),
          ),
        ),
        Container(height: 1, color: AppColors.black),
      ],
    );
  }
}

// 홈 화면의 누적 기록 글자. 러닝 화면은 원래 크기와 색을 그대로 씁니다.
const double _homeTotalSize = 33;

// 세 칸의 숫자 크기가 달라도 이름 줄이 같은 높이에 오도록, 숫자 자리 높이를
// 고정하고 아래에 붙입니다.
const double _homeNumberBox = 40;
const double _homeNumberGap = AppSpacing.xs + 1;

Widget _homeNumber(Widget child) {
  return SizedBox(
    height: _homeNumberBox,
    child: Align(alignment: Alignment.bottomLeft, child: child),
  );
}

final TextStyle _homeTotalLabel = AppTheme.sans.copyWith(
  fontSize: 14,
  color: AppColors.label,
);

class TotalBlock extends StatelessWidget {
  final String value;
  final String label;
  final bool padLeft;

  // 러닝 화면처럼 세 칸을 가운데 정렬로 쓸 때
  final bool center;

  // 홈 화면: 숫자를 조금 크게, 이름은 고딕 회색으로
  final bool home;

  const TotalBlock({
    super.key,
    required this.value,
    required this.label,
    this.padLeft = false,
    this.center = false,
    this.home = false,
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
          if (home)
            _homeNumber(
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(
                  value,
                  style: AppTheme.serifNumber.copyWith(
                    fontSize: _homeTotalSize,
                  ),
                ),
              ),
            )
          else
            // 숫자가 길어도 칸을 넘지 않게 줄여서 맞춥니다.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: center ? Alignment.center : Alignment.centerLeft,
              child: Text(value, style: AppTheme.number.copyWith(fontSize: 27)),
            ),
          const SizedBox(height: _homeNumberGap),
          Text(
            label,
            style: home
                ? _homeTotalLabel
                : textTheme.bodyMedium?.copyWith(color: AppColors.mute),
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
                _homeNumber(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: 30,
                      height: 2,
                      color: AppColors.black,
                    ),
                  ),
                )
              else
                _homeNumber(
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      '$rank위',
                      style: AppTheme.serifNumber.copyWith(
                        fontSize: _homeTotalSize,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: _homeNumberGap),
              Text(
                '거리 순위',
                style: _homeTotalLabel,
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
  // 위 줄 굵기. 아래 줄은 항상 1입니다.
  final double thick;

  const DoubleRule({super.key, this.thick = 2.4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: thick, color: AppColors.black),
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

// 내 캐릭터 / 랭킹 카드가 같이 쓰는 모양과 글자
BoxDecoration _shortcutDecoration(Color color) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(AppRadius.md),
    border: Border.all(color: AppColors.black, width: 1.4),
  );
}

final TextStyle _shortcutCaption = AppTheme.caption.copyWith(
  fontFamily: AppTheme.sansFont,
  fontWeight: FontWeight.w500,
  fontSize: 11,
);
final TextStyle _shortcutTitle = AppTheme.serifNumber.copyWith(
  fontSize: 20,
  color: AppColors.black,
);
final TextStyle _shortcutSub = AppTheme.sans.copyWith(
  fontSize: 14,
  color: AppColors.label,
);

class RunnerCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const RunnerCard({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 테두리 안쪽으로만 캐릭터가 보이게 자릅니다. 랭킹 카드와 같은 테두리라
        // 두 카드의 글자가 같은 자리에서 시작합니다.
        clipBehavior: Clip.antiAlias,
        decoration: _shortcutDecoration(AppColors.cream),
        child: Stack(
          children: [
            // 캐릭터는 오른쪽 아래에 붙여서 얼굴만 나오게 잘립니다.
            Positioned(
              right: -44,
              bottom: -192,
              width: 170,
              height: 300,
              child: const RunnerFigure(showGround: false),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MY RUNNER', style: _shortcutCaption),
                  const SizedBox(height: AppSpacing.sm),
                  Text('내 캐릭터', style: _shortcutTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    EquipmentRules.equippedSetName(user),
                    style: _shortcutSub,
                  ),
                ],
              ),
            ),
          ],
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
        decoration: _shortcutDecoration(AppColors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RANKING', style: _shortcutCaption),
            const SizedBox(height: AppSpacing.sm),
            Text('랭킹', style: _shortcutTitle),
            const SizedBox(height: AppSpacing.xs),
            Text('전체 순위 보기', style: _shortcutSub),
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
                        border: Border.all(color: AppColors.accent, width: 1.5),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accentDeep, width: 1.2),
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
          Text('$gold', style: AppTheme.serifNumber.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}
