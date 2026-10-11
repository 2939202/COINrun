import 'package:flutter/material.dart';

import '../game/character_outfit.dart';
import '../game/equipment_rules.dart';
import '../game/pvp_battle.dart';
import '../game/run_insights.dart';
import '../game/run_rules.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';
import '../services/ranking_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'character_view.dart';
import 'gold_coin.dart';
import 'notched_box.dart';
import 'segment_bar.dart';
import 'run_app_bar.dart' show GoldColors;

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

// 홈 가운데의 네모 카드들. 옆으로 넘겨 봅니다.
//
//   [게임 플레잉] [내 캐릭터] [AI 평가] [랭킹]
//
// 화면에는 언제나 두 장이 꽉 차게 보이고, 한 번 밀면 한 장씩 넘어갑니다.
// 처음에는 내 캐릭터와 AI 평가가 보입니다. 랭킹은 오른쪽으로 한 번,
// 게임 플레잉은 왼쪽으로 한 번 넘겨야 보입니다.
class ShortcutsCarousel extends StatefulWidget {
  final UserModel user;
  final Stream<InsightReport> weekInsight;
  final VoidCallback onPvp;
  final VoidCallback onCharacter;
  final VoidCallback onAiReport;
  final VoidCallback onRanking;

  const ShortcutsCarousel({
    super.key,
    required this.user,
    required this.weekInsight,
    required this.onPvp,
    required this.onCharacter,
    required this.onAiReport,
    required this.onRanking,
  });

  // 정사각형보다 살짝 눌린 가로 직사각형
  static const double height = 150;
  static const int cardCount = 4;

  // 처음 화면 왼쪽에 오는 카드 (0: 게임 플레잉, 1: 내 캐릭터)
  static const int firstPage = 1;

  @override
  State<ShortcutsCarousel> createState() => _ShortcutsCarouselState();
}

class _ShortcutsCarouselState extends State<ShortcutsCarousel> {
  // 한 페이지 = 화면 폭의 절반 = 카드 한 장. 그래서 두 장씩 보이고 한 장씩 넘어갑니다.
  late final PageController _pages = PageController(
    viewportFraction: 0.5,
    initialPage: ShortcutsCarousel.firstPage,
  );
  int _page = ShortcutsCarousel.firstPage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      PvpCard(user: widget.user, onTap: widget.onPvp),
      RunnerCard(user: widget.user, onTap: widget.onCharacter),
      AiReportCard(report: widget.weekInsight, onTap: widget.onAiReport),
      RankingCard(onTap: widget.onRanking),
    ];
    // 두 장이 한 화면이라, 멈출 수 있는 자리는 카드 수 - 1개입니다.
    const int positions = ShortcutsCarousel.cardCount - 1;

    return Column(
      children: [
        SizedBox(
          height: ShortcutsCarousel.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 카드마다 양옆에 gap/2씩 여백을 줍니다. 그러면 바깥쪽 카드 가장자리가
              // 화면 여백보다 gap/2 안쪽으로 들어가므로, 그만큼 넓혀서 다른 줄과 맞춥니다.
              const double gap = AppSpacing.md;
              return OverflowBox(
                maxWidth: constraints.maxWidth + gap,
                minWidth: constraints.maxWidth + gap,
                child: PageView(
                  controller: _pages,
                  padEnds: false,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    for (final card in cards)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: gap / 2,
                        ),
                        child: card,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        // 지금 어디쯤 보고 있는지 점으로 보여줍니다.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < positions; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.black : AppColors.sand,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// 홈 네모 카드들이 같이 쓰는 모양과 글자
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
            // 오른쪽 아래에 3D 캐릭터 얼굴. 누르면 카드가 눌리도록 손가락은 넘깁니다.
            Positioned(
              right: 0,
              bottom: 0,
              width: 112,
              height: 112,
              child: IgnorePointer(
                child: CharacterView(
                  me: CharacterOutfit.partsFor(
                    user.look ?? CharacterLook.female,
                    user.equippedSetId,
                  ),
                  face: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md - 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MY RUNNER', style: _shortcutCaption),
                  const SizedBox(height: AppSpacing.xs + 2),
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

// 랭킹 카드는 교환 버튼과 같은 금속 금색입니다. 갈색 글자는 금색에 묻혀서
// 글자는 또렷한 먹색으로 씁니다.
class RankingCardState extends State<RankingCard> {
  late final Stream<List<RankingEntry>> _top = RankingRepository.instance
      .watchTop(RankingKind.distance, limit: 1);

  static const Color _ink = AppColors.black;
  static const Color _inkSoft = Color(0xFF2E2620);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md - 2),
        decoration: BoxDecoration(
          gradient: GoldColors.metal,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: GoldColors.edge, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RANKING', style: _shortcutCaption.copyWith(color: _inkSoft)),
            const SizedBox(height: AppSpacing.xs + 2),
            Text('랭킹', style: _shortcutTitle.copyWith(color: _ink)),
            const SizedBox(height: AppSpacing.xs),
            Text('전체 순위 보기', style: _shortcutSub.copyWith(color: _inkSoft)),
            const Spacer(),
            Container(height: 1, color: _ink.withValues(alpha: 0.35)),
            const SizedBox(height: AppSpacing.xs + 2),

            // 1등만 살짝 보여줍니다.
            StreamBuilder<List<RankingEntry>>(
              stream: _top,
              builder: (context, snapshot) {
                final List<RankingEntry> top = snapshot.data ?? const [];
                if (top.isEmpty) {
                  return Text(
                    '아직 아무도 없어요',
                    style: textTheme.bodyMedium?.copyWith(color: _inkSoft),
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
                        color: const Color(0xFFFFF6D5),
                        shape: BoxShape.circle,
                        border: Border.all(color: GoldColors.edge, width: 1.5),
                      ),
                      child: Text(
                        '1',
                        style: AppTheme.number.copyWith(
                          fontSize: 13,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        first.nickname,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          color: _ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatKm(first.totalDistance),
                      style: AppTheme.number.copyWith(
                        fontSize: 15,
                        color: _ink,
                      ),
                    ),
                    Text(
                      ' km',
                      style: textTheme.labelMedium?.copyWith(color: _inkSoft),
                    ),
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

// 게임 플레잉(PVP) 카드. 검은 바탕에 겨루는 사람 무늬
class PvpCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const PvpCard({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Fighter me = Fighter(
      id: '',
      name: user.nickname,
      level: user.level,
      totalKm: user.totalDistance / 1000,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: _shortcutDecoration(AppColors.black),
        child: Stack(
          children: [
            const Positioned(
              right: -18,
              bottom: -18,
              child: Icon(
                Icons.sports_kabaddi,
                size: 120,
                color: AppColors.inkSoft,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GAME PLAYING',
                    style: _shortcutCaption.copyWith(
                      color: AppColors.accentOnDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '게임 플레잉',
                    style: _shortcutTitle.copyWith(color: AppColors.white),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'PVP 대결',
                    style: _shortcutSub.copyWith(color: AppColors.sandOnDark),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${me.power}',
                        style: AppTheme.serifNumber.copyWith(
                          fontSize: 26,
                          color: AppColors.accentOnDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '전투력',
                          style: _shortcutSub.copyWith(
                            fontSize: 12,
                            color: AppColors.sandOnDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

// AI 평가 카드. 이번 주 등급과 한 줄 평을 보여줍니다.
class AiReportCard extends StatelessWidget {
  final Stream<InsightReport> report;
  final VoidCallback onTap;

  const AiReportCard({super.key, required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        // 랭킹 카드와 같은 흰 바탕
        decoration: _shortcutDecoration(AppColors.white),
        child: StreamBuilder<InsightReport>(
          stream: report,
          builder: (context, snapshot) {
            final textTheme = Theme.of(context).textTheme;
            final InsightReport? data = snapshot.data;
            final bool empty = data == null || !data.hasAnyRun;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI REPORT', style: _shortcutCaption),
                const SizedBox(height: AppSpacing.sm),
                Text('AI 평가', style: _shortcutTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data?.headline ?? '주간·월간 분석',
                  style: _shortcutSub,
                  // 카드 높이가 정해져 있어서 한 줄만. 전체 문장은 AI 평가 화면에 있습니다.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(height: 1, color: AppColors.sand),
                const SizedBox(height: AppSpacing.sm),
                // 등급 없이 이번 주 숫자만 보여줍니다. (랭킹 카드 아랫줄과 같은 모양)
                if (empty)
                  Text(
                    '기록이 쌓이면 평가해요',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.mute,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '이번 주',
                          style: textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        data.current.km.toStringAsFixed(1),
                        style: AppTheme.number.copyWith(fontSize: 17),
                      ),
                      Text(' km', style: textTheme.labelMedium),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${data.current.runs}',
                        style: AppTheme.number.copyWith(fontSize: 17),
                      ),
                      Text(' 회', style: textTheme.labelMedium),
                    ],
                  ),
              ],
            );
          },
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
          const GoldCoin(),
          const SizedBox(width: AppSpacing.xs + 1),
          Text('$gold', style: AppTheme.serifNumber.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}
