import 'package:flutter/material.dart';

import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../game/run_rules.dart';
import '../models/equipment_set.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_coin.dart';
import '../widgets/notched_box.dart';
import '../widgets/runner_figure.dart';
import '../widgets/segment_bar.dart';
import 'shop_screen.dart';

// ============================================================
// 내 캐릭터
//
// 배경은 크림에 점무늬를 깔고, 그 위에 캐릭터를 세웁니다.
// 아래에는 지금 능력치와, 장비를 사러 가는 길(잡화점)을 둡니다.
// ============================================================
class ProfileScreen extends StatelessWidget {
  final String userId;
  final UserModel userData;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  // 아직 사지 않은 세트 중 가장 싼 것 = 다음에 노릴 장비. 다 샀으면 null입니다.
  EquipmentSet? get _nextSet {
    for (final set in EquipmentCatalog.all) {
      if (!userData.owns(set.id)) return set;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamDeep,
      appBar: AppBar(
        backgroundColor: AppColors.creamDeep,
        title: const Text('내 캐릭터'),
        actions: [
          _GoldChip(gold: userData.gold),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: CustomPaint(
        painter: const _DotPainter(),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      _NamePlate(user: userData),
                      const SizedBox(height: AppSpacing.md),
                      const SizedBox(height: 300, child: RunnerFigure()),
                      const SizedBox(height: AppSpacing.lg),
                      _StatsCard(user: userData),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
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
                            builder: (context) => ShopScreen(userId: userId),
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
                              _nextSet == null
                                  ? '전부 갖췄습니다'
                                  : '다음 단계 · ${_nextSet!.name}',
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
              ),
            ],
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

// 능력치 카드
class _StatsCard extends StatelessWidget {
  final UserModel user;

  const _StatsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final EquipmentSet? gear = EquipmentRules.equippedSet(user);
    final int needed = RunRules.expToNextLevel(user.level);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.black, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'RUNNER STATS',
                style: AppTheme.caption.copyWith(fontSize: 11),
              ),
              const Spacer(),
              Text(
                '장착 · ${EquipmentRules.equippedSetName(user)}',
                style: textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _StatRow(label: '힘', value: gear?.power ?? 0),
          const SizedBox(height: AppSpacing.md),
          _StatRow(label: '체력', value: gear?.stamina ?? 0),
          const SizedBox(height: AppSpacing.md),
          _StatRow(label: '속도', value: gear?.speed ?? 0),

          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.sand),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('경험치 ', style: textTheme.bodyMedium),
              Text('${user.exp}', style: textTheme.titleMedium),
              Text(
                ' / $needed',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.mute),
              ),
              const Spacer(),
              Text(
                '다음 레벨까지 ${needed - user.exp}',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.mute),
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
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: SegmentBar(
            progress: value / max,
            filledColor: AppColors.black,
            emptyColor: AppColors.cream,
            height: 12,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: AppTheme.number.copyWith(fontSize: 18),
          ),
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
