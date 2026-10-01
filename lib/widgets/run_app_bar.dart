import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import 'gold_coin.dart';

// ============================================================
// 러닝 / 코스 러닝 화면이 같이 쓰는 앱바
//
//   ← 러닝            [Lv.1 · 🪙 0] [⇄]
//   ← 코스 러닝        [Lv.1 · 🪙 0] [⇄]
//
// 두 화면은 같은 자리에서 서로 바뀌는 한 화면처럼 보여야 해서, 제목 크기와 오른쪽
// 버튼을 똑같이 맞춥니다. ⇄를 누르면 다른 쪽이 오른쪽에서 밀려 들어오고,
// ←는 어느 쪽에서든 홈으로 나갑니다.
// ============================================================
class RunAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String userId;
  final VoidCallback onSwap;

  const RunAppBar({
    super.key,
    required this.title,
    required this.userId,
    required this.onSwap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        RunUserBadge(userId: userId),
        const SizedBox(width: AppSpacing.sm),
        SwapModeButton(onTap: onSwap),
        const SizedBox(width: AppSpacing.md),
      ],
    );
  }
}

// 러닝 <-> 코스 러닝 바꾸기. 흰 네모에 검은 테두리, 검은 화살표
class SwapModeButton extends StatelessWidget {
  final VoidCallback onTap;

  const SwapModeButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '러닝 / 코스 러닝 바꾸기',
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.black, width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.swap_horiz, color: AppColors.black, size: 22),
          ),
        ),
      ),
    );
  }
}

// 앱바 오른쪽의 레벨/골드 표시 (Firestore 값을 실시간으로 보여줌)
// 러닝 화면은 1초마다 다시 그려지므로, 스트림을 State에 한 번만 만들어 둡니다.
class RunUserBadge extends StatefulWidget {
  final String userId;

  const RunUserBadge({super.key, required this.userId});

  @override
  State<RunUserBadge> createState() => _RunUserBadgeState();
}

class _RunUserBadgeState extends State<RunUserBadge> {
  late final Stream<UserModel?> _userStream = UserRepository.instance.watchUser(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, snapshot) {
        final UserModel? user = snapshot.data;
        if (user == null) return const SizedBox.shrink();
        final TextStyle? style = Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontSize: 13);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lv.${user.level} · ', style: style),
              const GoldCoin(size: 15),
              Text(' ${user.gold}', style: style),
            ],
          ),
        );
      },
    );
  }
}
