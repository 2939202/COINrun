import 'package:flutter/material.dart';

import '../game/character_outfit.dart';
import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../game/honor_level.dart';
import '../game/run_rules.dart';
import '../models/equipment_set.dart';
import '../models/user_model.dart';
import '../services/course_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/character_view.dart';
import '../widgets/gold_coin.dart';
import '../widgets/notched_box.dart';
import '../widgets/run_app_bar.dart' show GoldColors;
import '../widgets/segment_bar.dart';
import 'shop_screen.dart';

// ============================================================
// 내 캐릭터
//
// 배경은 크림에 점무늬를 깔고, 그 위에 캐릭터를 세웁니다.
// 아래에는 지금 능력치와, 장비를 사러 가는 길(잡화점)을 둡니다.
// ============================================================
class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// 유저 문서를 계속 지켜봅니다. 잡화점에서 옷을 입고 돌아오면 캐릭터가 바로 갈아입습니다.
class _ProfileScreenState extends State<ProfileScreen> {
  late final Stream<UserModel?> _user = UserRepository.instance.watchUser(
    widget.userId,
  );

  // 아직 사지 않은 세트 중 가장 싼 것 = 다음에 노릴 장비. 다 샀으면 null입니다.
  static EquipmentSet? _nextSet(UserModel user) {
    for (final set in EquipmentCatalog.all) {
      if (!user.owns(set.id)) return set;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _user,
      builder: (context, snapshot) {
        final UserModel? user = snapshot.data;
        if (user == null) {
          return const Scaffold(
            backgroundColor: AppColors.creamDeep,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _build(context, user);
      },
    );
  }

  Widget _build(BuildContext context, UserModel user) {
    final EquipmentSet? next = _nextSet(user);
    return Scaffold(
      backgroundColor: AppColors.creamDeep,
      appBar: AppBar(
        backgroundColor: AppColors.creamDeep,
        title: const Text('내 캐릭터'),
        actions: [
          _GoldChip(gold: user.gold),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: CustomPaint(
        painter: const _DotPainter(),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                _NamePlate(user: user),
                const SizedBox(height: AppSpacing.sm),
                _HonorLine(userId: widget.userId),
                // 캐릭터가 남는 자리를 전부 씁니다.
                Expanded(
                  child: CharacterView(
                    me: CharacterOutfit.partsFor(
                      user.look ?? CharacterLook.female,
                      user.equippedSetId,
                    ),
                  ),
                ),
                _StatsCard(user: user),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: NotchedBox(
                        cut: 12,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md - 2,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ShopScreen(userId: widget.userId),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '잡화점',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: AppColors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              next == null
                                  ? '전부 갖췄습니다'
                                  : '다음 단계 · ${next.name}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.sand),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(child: _HouseSlot()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 이름표
class _NamePlate extends StatelessWidget {
  final UserModel user;

  const _NamePlate({required this.user});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.black, width: 1.6),
      ),
      child: Column(
        children: [
          Text(
            'LV.${user.level} · ${RunRules.tierName(user.level).split(' ').first.toUpperCase()}',
            style: AppTheme.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(user.nickname, style: textTheme.titleLarge),
        ],
      ),
    );
  }
}

// 능력치 카드 (작게)
//
//   장착 · 천옷                         경험치 120 / 300
//   힘        5   체력      3   속도      0
//   ━━━━────      ━━──────      ────────
class _StatsCard extends StatelessWidget {
  final UserModel user;

  const _StatsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final EquipmentSet? gear = EquipmentRules.equippedSet(user);
    final int needed = RunRules.expToNextLevel(user.level);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.black, width: 1.4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '장착 · ${EquipmentRules.equippedSetName(user)}',
                  style: AppTheme.sans.copyWith(
                    fontSize: 13,
                    fontWeight: AppTheme.sansMedium,
                    color: AppColors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '경험치 ${user.exp} / $needed',
                style: AppTheme.sans.copyWith(
                  fontSize: 12,
                  color: AppColors.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatRow(label: '힘', value: gear?.power ?? 0),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatRow(label: '체력', value: gear?.stamina ?? 0),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatRow(label: '속도', value: gear?.speed ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;

  // 막대가 가득 차는 기준. 고급 세트(15)보다 조금 위로 잡습니다.
  static const int max = 20;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTheme.sans.copyWith(
                fontSize: 12,
                color: AppColors.label,
              ),
            ),
            const Spacer(),
            Text('$value', style: AppTheme.number.copyWith(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 3),
        SegmentBar(
          progress: value / max,
          filledColor: AppColors.black,
          emptyColor: AppColors.cream,
          height: 6,
        ),
      ],
    );
  }
}

// 아직 만들지 않은 자리
class _HouseSlot extends StatelessWidget {
  const _HouseSlot();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DashedBox(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      child: Row(
        children: [
          const Icon(Icons.home_outlined, color: AppColors.accent, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '나의 집 · 길드',
                  style: textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text('준비 중', style: textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldChip extends StatelessWidget {
  final int gold;

  const _GoldChip({required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm - 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.accent, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GoldCoin(size: 20),
          const SizedBox(width: AppSpacing.sm - 2),
          Text('$gold', style: AppTheme.number.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}

// 배경 점무늬
class _DotPainter extends CustomPainter {
  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.sand.withValues(alpha: 0.55);
    const double step = 16;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) => false;
}

// 이름표 아래 명예 레벨 한 줄. 사설 코스를 만들고 하트를 받으면 오릅니다.
class _HonorLine extends StatefulWidget {
  final String userId;

  const _HonorLine({required this.userId});

  @override
  State<_HonorLine> createState() => _HonorLineState();
}

class _HonorLineState extends State<_HonorLine> {
  late final Stream<HonorLevel> _honor = CourseRepository.instance.watchHonor(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HonorLevel>(
      stream: _honor,
      builder: (context, snapshot) {
        final HonorLevel? honor = snapshot.data;
        if (honor == null) return const SizedBox(height: 18);
        final TextStyle style = AppTheme.sans.copyWith(
          fontSize: 12.5,
          color: AppColors.label,
        );
        if (honor.level == 0) {
          return Text('사설 코스를 만들면 명예 레벨이 오릅니다', style: style);
        }
        final int? left = honor.heartsToNext;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: GoldColors.metal,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: GoldColors.edge),
              ),
              child: Text(
                '명예 Lv.${honor.level}',
                style: AppTheme.sans.copyWith(
                  fontSize: 12,
                  fontWeight: AppTheme.sansMedium,
                  color: AppColors.black,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '코스 ${honor.courses}개 · 하트 ${honor.hearts}'
              '${left == null ? '' : ' · 다음까지 $left'}',
              style: style,
            ),
          ],
        );
      },
    );
  }
}
