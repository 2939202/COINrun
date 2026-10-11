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
import 'shop_screen.dart';

// ============================================================
// 내 캐릭터
//
// 흰 바탕 전체에 3D 캐릭터를 세우고, 그 위에 작은 것들을 얹습니다.
//
//   [여자|남자]          LV.10 · BRONZE          (i)
//                          닉네임                힘    3
//                                                체력  3
//               (3D 캐릭터, 숨 쉬는 중)           속도  2
//                                                명예  Lv.1
//   [잡화점 (반투명)]           [나의 집 · 길드 (반투명)]
//
// (i)를 누르면 오른쪽 능력치가 열리고 닫힙니다.
// 캐릭터는 가로로 끌면 돌고, 빠르게 두 번 치면 붉어지며 콩콩 뜁니다.
// 남/여를 아직 고르지 않은 사람에게는 물음표를 보여줍니다.
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
  late final Stream<HonorLevel> _honor = CourseRepository.instance.watchHonor(
    widget.userId,
  );

  bool _showStats = false;

  // 고르자마자 바뀌어 보이게 저장이 끝나기 전 값을 잠깐 들고 있습니다.
  CharacterLook? _pending;

  // 아직 사지 않은 세트 중 가장 싼 것 = 다음에 노릴 장비. 다 샀으면 null입니다.
  static EquipmentSet? _nextSet(UserModel user) {
    for (final set in EquipmentCatalog.all) {
      if (!user.owns(set.id)) return set;
    }
    return null;
  }

  Future<void> _pickLook(CharacterLook look) async {
    setState(() => _pending = look);
    try {
      await UserRepository.instance.setLook(widget.userId, look);
    } catch (error) {
      if (!mounted) return;
      setState(() => _pending = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 눌러 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _user,
      builder: (context, snapshot) {
        final UserModel? user = snapshot.data;
        if (user == null) {
          return const Scaffold(
            backgroundColor: AppColors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_pending != null && _pending == user.look) _pending = null;
        return _build(context, user, _pending ?? user.look);
      },
    );
  }

  Widget _build(BuildContext context, UserModel user, CharacterLook? look) {
    final EquipmentSet? next = _nextSet(user);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: const Text('내 캐릭터'),
        actions: [
          _GoldChip(gold: user.gold),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // 캐릭터가 화면 전체를 씁니다. 위아래 상자는 반투명이라 뒤로 비칩니다.
            Positioned.fill(
              top: 44,
              child: look == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '?',
                            style: AppTheme.serifNumber.copyWith(
                              fontSize: 96,
                              color: AppColors.sand,
                            ),
                          ),
                          Text(
                            '왼쪽 위에서 여자나 남자를 골라 주세요',
                            style: AppTheme.sans.copyWith(
                              fontSize: 13,
                              color: AppColors.label,
                            ),
                          ),
                        ],
                      ),
                    )
                  : CharacterView(
                      me: CharacterOutfit.partsFor(look, user.equippedSetId),
                    ),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: 0,
              right: 0,
              child: Center(child: _NamePlate(user: user)),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.lg,
              child: Row(
                children: [
                  for (final option in CharacterLook.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: _LookChip(
                        label: option.label,
                        selected: option == look,
                        onTap: () => _pickLook(option),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: AppSpacing.sm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '능력치',
                    onPressed: () => setState(() => _showStats = !_showStats),
                    icon: Icon(
                      _showStats ? Icons.info : Icons.info_outline,
                      color: AppColors.black,
                    ),
                  ),
                  if (_showStats)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: StreamBuilder<HonorLevel>(
                        stream: _honor,
                        builder: (context, honor) =>
                            _StatsColumn(user: user, honor: honor.data),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Row(
                children: [
                  Expanded(
                    child: NotchedBox(
                      cut: 12,
                      color: AppColors.black.withValues(alpha: 0.72),
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
                            next == null ? '전부 갖췄습니다' : '다음 단계 · ${next.name}',
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
    );
  }
}

// 이름표: 테두리 없이 작게
class _NamePlate extends StatelessWidget {
  final UserModel user;

  const _NamePlate({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LV.${user.level} · ${RunRules.tierName(user.level).split(' ').first.toUpperCase()}',
          style: AppTheme.caption.copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 1),
        Text(
          user.nickname,
          style: AppTheme.serifNumber.copyWith(
            fontSize: 17,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

// 남/여 고르기
class _LookChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LookChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.black, width: 1.2),
        ),
        child: Text(
          label,
          style: AppTheme.sans.copyWith(
            fontSize: 12,
            fontWeight: AppTheme.sansMedium,
            color: selected ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}

// 오른쪽 위 능력치. 테두리 없이 세로로: 힘, 체력, 속도, 명예
class _StatsColumn extends StatelessWidget {
  final UserModel user;
  final HonorLevel? honor;

  const _StatsColumn({required this.user, required this.honor});

  @override
  Widget build(BuildContext context) {
    final EquipmentSet? gear = EquipmentRules.equippedSet(user);
    final int honorLevel = honor?.level ?? 0;
    final List<(String, String)> rows = [
      ('힘', '${gear?.power ?? 0}'),
      ('체력', '${gear?.stamina ?? 0}'),
      ('속도', '${gear?.speed ?? 0}'),
      ('명예', honorLevel == 0 ? '-' : 'Lv.$honorLevel'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTheme.sans.copyWith(
                    fontSize: 12,
                    color: AppColors.label,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 36,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: AppTheme.number.copyWith(fontSize: 15),
                  ),
                ),
              ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: _house(textTheme),
    );
  }

  Widget _house(TextTheme textTheme) {
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
