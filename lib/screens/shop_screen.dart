import 'package:flutter/material.dart';

import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../models/equipment_set.dart';
import '../models/user_model.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';

// ============================================================
// 잡화점 - 장비 세트를 사고 갈아입는 화면
//
// 러닝 화면과 달리 여기는 머무르는 곳이라, 미니멀하게 갈 이유가 없습니다.
// 가게 간판과 등급 표시를 넣어 고르는 재미가 나게 했습니다.
// ============================================================
class ShopScreen extends StatefulWidget {
  final String userId;

  const ShopScreen({super.key, required this.userId});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // 스트림은 한 번만 만들어 둡니다. (build 안에서 만들면 다시 그릴 때마다 새로 연결됨)
  late final Stream<UserModel?> _userStream = UserRepository.instance.watchUser(
    widget.userId,
  );

  bool _isBusy = false; // 버튼을 두 번 누르지 못하게 잠그는 값

  // 사기/입기를 실행하고, 결과를 아래쪽 알림 띠로 알려줍니다.
  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    String message = successMessage;
    try {
      await action();
    } on EquipmentException catch (error) {
      message = error.message;
    } catch (_) {
      message = '잠시 후 다시 시도해 주세요.';
    }
    if (!mounted) return;
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('잡화점'),
        actions: [
          StreamBuilder<UserModel?>(
            stream: _userStream,
            builder: (context, snapshot) =>
                _GoldChip(gold: snapshot.data?.gold ?? 0),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userStream,
        builder: (context, snapshot) {
          final UserModel? user = snapshot.data;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _StoreSign(user: user),
              const SizedBox(height: AppSpacing.lg),
              for (int i = 0; i < EquipmentCatalog.all.length; i++) ...[
                _SetCard(
                  set: EquipmentCatalog.all[i],
                  tier: i + 1,
                  user: user,
                  isBusy: _isBusy,
                  onBuy: () => _run(
                    () => UserRepository.instance.buySet(
                      widget.userId,
                      EquipmentCatalog.all[i].id,
                    ),
                    '${EquipmentCatalog.all[i].name}을(를) 샀습니다.',
                  ),
                  onEquip: () => _run(
                    () => UserRepository.instance.equipSet(
                      widget.userId,
                      EquipmentCatalog.all[i].id,
                    ),
                    '${EquipmentCatalog.all[i].name}(으)로 갈아입었습니다.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

// 가게 간판
class _StoreSign extends StatelessWidget {
  final UserModel user;

  const _StoreSign({required this.user});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GENERAL STORE',
                  style: AppTheme.caption.copyWith(fontSize: 11),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '러너 잡화점',
                  style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '입은 장비 · ${EquipmentRules.equippedSetName(user)}',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.mute),
                ),
              ],
            ),
          ),
          const Icon(Icons.storefront_outlined, size: 54),
        ],
      ),
    );
  }
}

// 세트 한 장
class _SetCard extends StatelessWidget {
  final EquipmentSet set;
  final int tier;
  final UserModel user;
  final bool isBusy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _SetCard({
    required this.set,
    required this.tier,
    required this.user,
    required this.isBusy,
    required this.onBuy,
    required this.onEquip,
  });

  static const List<String> _roman = ['', 'I', 'II', 'III'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool isEquipped = user.equippedSetId == set.id;
    final bool owned = user.owns(set.id);
    final PurchaseCheck check = EquipmentRules.checkPurchase(user, set);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isEquipped ? AppColors.black : AppColors.sand,
          width: isEquipped ? 2 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TierIcon(roman: _roman[tier]),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'TIER ${_roman[tier]}',
                          style: AppTheme.caption.copyWith(fontSize: 11),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm - 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.accent),
                          ),
                          child: Text(
                            'Lv.${set.requiredLevel} 이상',
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.accent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(set.name, style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      set.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              _StatChip(label: '힘', value: set.power),
              const SizedBox(width: AppSpacing.sm - 2),
              _StatChip(label: '체력', value: set.stamina),
              const SizedBox(width: AppSpacing.sm - 2),
              _StatChip(label: '속도', value: set.speed),
              const Spacer(),
              Flexible(
                child: Text(
                  '골드·경험치 +${set.power}%',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.accent,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.sand),
          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              _Coin(),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatGold(set.price),
                style: AppTheme.number.copyWith(fontSize: 22),
              ),
              const Spacer(),
              if (!isEquipped && !check.isOk && !owned)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (check == PurchaseCheck.lockedByLevel)
                          const Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: AppColors.mute,
                          ),
                        Flexible(
                          child: Text(
                            check == PurchaseCheck.lockedByLevel
                                ? ' Lv.${set.requiredLevel}부터'
                                : '골드가 모자라요',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.mute,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _ActionButton(
                isEquipped: isEquipped,
                owned: owned,
                canBuy: check.isOk,
                isBusy: isBusy,
                onBuy: onBuy,
                onEquip: onEquip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 1,000 단위로 쉼표
  static String formatGold(int value) {
    final String text = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) out.write(',');
      out.write(text[i]);
    }
    return out.toString();
  }
}

class _TierIcon extends StatelessWidget {
  final String roman;

  const _TierIcon({required this.roman});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.checkroom, size: 26),
          const SizedBox(height: 2),
          Text(roman, style: AppTheme.number.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13),
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cream,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 1.6),
      ),
      child: Text(
        'G',
        style: AppTheme.number.copyWith(fontSize: 11, color: AppColors.gold),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool isEquipped;
  final bool owned;
  final bool canBuy;
  final bool isBusy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _ActionButton({
    required this.isEquipped,
    required this.owned,
    required this.canBuy,
    required this.isBusy,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (isEquipped) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          '입고 있음',
          style: textTheme.titleMedium?.copyWith(
            color: AppColors.white,
            fontSize: 14,
          ),
        ),
      );
    }

    final bool enabled = !isBusy && (owned || canBuy);
    return GestureDetector(
      onTap: enabled ? (owned ? onEquip : onBuy) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: enabled ? AppColors.black : AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          owned ? '입기' : '구매',
          style: textTheme.titleMedium?.copyWith(
            color: enabled ? AppColors.white : AppColors.mute,
            fontSize: 15,
          ),
        ),
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.accent, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Coin(),
          const SizedBox(width: AppSpacing.sm - 2),
          Text('$gold', style: AppTheme.number.copyWith(fontSize: 16)),
          const SizedBox(width: 2),
          Text('G', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
