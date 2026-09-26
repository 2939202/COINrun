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
// [지금은 뼈대만입니다]
//   동작(사기/입기/못 사는 이유 알려주기)은 다 되지만, 보여주는 모양은
//   나중에 디자인 시안이 정해지면 다시 만듭니다. 그때 고치는 건 이 파일 하나뿐이고,
//   규칙(game/equipment_rules.dart)과 저장(services/user_repository.dart)은 그대로 씁니다.
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
  Future<void> _run(Future<void> Function() action, String successMessage) async {
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
      appBar: AppBar(title: const Text('잡화점')),
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
              Text(
                '보유 골드 ${user.gold} G  ·  입은 장비 ${EquipmentRules.equippedSetName(user)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final set in EquipmentCatalog.all) ...[
                _SetRow(
                  set: set,
                  user: user,
                  isBusy: _isBusy,
                  onBuy: () => _run(
                    () => UserRepository.instance.buySet(widget.userId, set.id),
                    '${set.name}을(를) 샀습니다.',
                  ),
                  onEquip: () => _run(
                    () =>
                        UserRepository.instance.equipSet(widget.userId, set.id),
                    '${set.name}(으)로 갈아입었습니다.',
                  ),
                ),
                const Divider(height: AppSpacing.xl),
              ],
            ],
          );
        },
      ),
    );
  }
}

// 세트 한 줄: 이름 / 능력치 / 가격 + 버튼 하나
class _SetRow extends StatelessWidget {
  final EquipmentSet set;
  final UserModel user;
  final bool isBusy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _SetRow({
    required this.set,
    required this.user,
    required this.isBusy,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool isEquipped = user.equippedSetId == set.id;
    final bool owned = user.owns(set.id);
    final PurchaseCheck check = EquipmentRules.checkPurchase(user, set);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(set.name, style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(set.description, style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '힘 ${set.power}  ·  체력 ${set.stamina}  ·  속도 ${set.speed}',
          style: textTheme.titleMedium,
        ),
        Text(
          '골드 +${set.power}%  ·  경험치 +${set.stamina}%',
          style: textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${set.price} G  ·  Lv.${set.requiredLevel} 이상', style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.md),
        if (isEquipped)
          const Text('입고 있음')
        else if (owned)
          ElevatedButton(
            onPressed: isBusy ? null : onEquip,
            child: const Text('입기'),
          )
        else
          Row(
            children: [
              ElevatedButton(
                onPressed: isBusy || !check.isOk ? null : onBuy,
                child: const Text('사기'),
              ),
              if (!check.isOk) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    check.message(set),
                    style: textTheme.labelMedium,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
