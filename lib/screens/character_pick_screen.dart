import 'package:flutter/material.dart';

import '../game/character_outfit.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/character_view.dart';

// ============================================================
// 캐릭터 고르기 (처음 한 번)
//
// 아직 남/여를 고르지 않은 사람에게 홈 대신 이 화면을 띄웁니다. (main_screen.dart)
// 한 번 고르면 바꿀 수 없습니다. 저장되면 홈이 알아서 다시 그려집니다.
//
//   캐릭터를 골라 주세요
//   한 번 고르면 바꿀 수 없어요.
//        [남자 3D]   [여자 3D]
//        [ 남자 ]    [ 여자 ]
//   [          이 캐릭터로 시작          ]
// ============================================================
class CharacterPickScreen extends StatefulWidget {
  final String userId;

  const CharacterPickScreen({super.key, required this.userId});

  @override
  State<CharacterPickScreen> createState() => _CharacterPickScreenState();
}

class _CharacterPickScreenState extends State<CharacterPickScreen> {
  // 3D 화면에서 왼쪽이 남자, 오른쪽이 여자입니다.
  static const List<CharacterLook> _order = [
    CharacterLook.male,
    CharacterLook.female,
  ];

  CharacterLook? _picked;
  bool _saving = false;

  Future<void> _start() async {
    final CharacterLook? look = _picked;
    if (look == null) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${look.label}로 시작할까요?'),
        content: const Text('나중에 바꿀 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('다시 고르기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('시작'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await UserRepository.instance.chooseLook(widget.userId, look);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 눌러 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                '캐릭터를 골라 주세요',
                textAlign: TextAlign.center,
                style: AppTheme.serifNumber.copyWith(
                  fontSize: 24,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '한 번 고르면 바꿀 수 없어요.',
                textAlign: TextAlign.center,
                style: AppTheme.sans.copyWith(
                  fontSize: 13,
                  color: AppColors.label,
                ),
              ),
              Expanded(
                child: CharacterView(
                  me: CharacterOutfit.partsFor(_order[0], null),
                  foe: CharacterOutfit.partsFor(_order[1], null),
                  pair: true,
                ),
              ),
              Row(
                children: [
                  for (final look in _order) ...[
                    if (look != _order.first)
                      const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _LookButton(
                        label: look.label,
                        selected: _picked == look,
                        onTap: () => setState(() => _picked = look),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _picked == null || _saving ? null : _start,
                  child: Text(_saving ? '저장하는 중' : '이 캐릭터로 시작'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LookButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LookButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.black, width: 1.6),
        ),
        child: Text(
          label,
          style: AppTheme.sans.copyWith(
            fontSize: 16,
            fontWeight: AppTheme.sansMedium,
            color: selected ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}
