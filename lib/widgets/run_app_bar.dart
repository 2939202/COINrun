import 'dart:async';

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

// 러닝 <-> 코스 러닝 바꾸기. 진짜 금괴처럼 보이는 금색 버튼
//
// 한 번 바꾸면 홈의 "시작"도 그 쪽으로 고정되는 중요한 버튼이라 눈에 띄게 만듭니다.
//   - 바탕: 밝은 금 -> 짙은 금을 여러 번 오가는 대각선 그라데이션 (금속 반사)
//   - 테두리: 짙은 구리빛 금 바깥선 + 안쪽 밝은 하이라이트 선 (도드라진 느낌)
//   - 반짝임: 30초마다 흰 빛줄기가 왼쪽 위에서 오른쪽 아래로 한 번 쓸고 지나갑니다
class SwapModeButton extends StatefulWidget {
  final VoidCallback onTap;

  const SwapModeButton({super.key, required this.onTap});

  @override
  State<SwapModeButton> createState() => _SwapModeButtonState();
}

class _SwapModeButtonState extends State<SwapModeButton>
    with SingleTickerProviderStateMixin {
  static const double _size = 38;

  // 30초에 한 번 0.7초 동안 빛줄기가 지나갑니다. 너무 자주 반짝이면 정신없습니다.
  // 쉬는 동안에는 애니메이션을 멈춰 둬서 화면을 다시 그리지 않습니다.
  static const Duration _shineEvery = Duration(seconds: 30);
  static const Duration _shineFor = Duration(milliseconds: 700);

  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: _shineFor,
  )..forward(); // 화면에 처음 나올 때 한 번
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_shineEvery, (_) => _shine.forward(from: 0));
  }

  @override
  void dispose() {
    _timer.cancel();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(AppRadius.sm);

    return Tooltip(
      message: '러닝 / 코스 러닝 바꾸기',
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: GoldColors.metal,
          border: Border.all(color: GoldColors.edge, width: 1.2),
          boxShadow: const [
            // 아래로 떨어지는 그림자 (금빛 번짐은 너무 튀어서 뺐습니다)
            BoxShadow(
              color: Color(0x553E2E1A),
              blurRadius: 3,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 안쪽 하이라이트 선. 위는 밝고 아래는 어두워서 볼록하게 보입니다.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: const Color(0x66F5EDE0), width: 1),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33FFFFFF),
                      Color(0x00FFFFFF),
                      Color(0x22000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
              // 지나가는 빛줄기
              AnimatedBuilder(
                animation: _shine,
                builder: (context, _) {
                  final double t = _shine.value;
                  if (t >= 1) return const SizedBox.shrink();
                  final double x = -1.6 + 3.2 * t;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(x - 0.6, -1),
                        end: Alignment(x + 0.6, 1),
                        colors: const [
                          Color(0x00FFFFFF),
                          Color(0x66FFF8EC), // 은은하게 한 번 스칩니다
                          Color(0x00FFFFFF),
                        ],
                        stops: const [0.35, 0.5, 0.65],
                      ),
                    ),
                  );
                },
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: widget.onTap,
                  splashColor: const Color(0x55E9DCC0),
                  highlightColor: const Color(0x33FFFFFF),
                  child: const Icon(
                    Icons.swap_horiz,
                    size: 23,
                    color: GoldColors.engraved,
                    // 금에 새긴 것처럼 아래쪽에 밝은 그림자를 한 줄 깝니다.
                    shadows: [
                      Shadow(color: Color(0x88EFE4CC), offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 금속 금색 (오래된 놋쇠)
//
// 번쩍이는 노란 금은 갈색 위주인 앱에서 혼자 튀어서, 채도를 낮춘 놋쇠빛으로 둡니다.
// 그래도 평평한 한 가지 색이면 금속이 아니라 종이처럼 보여서, 밝은 면과 어두운 면을
// 번갈아 놓아 빛이 반사되는 것처럼 만듭니다. (앱 갈색: accentOnDark #C9A87C, accent #8A6A3E)
class GoldColors {
  GoldColors._();

  static const Color edge = Color(0xFF7A5F3A); // 바깥 테두리 (짙은 놋쇠)
  static const Color engraved = Color(0xFF3E2E1A); // 놋쇠 위에 새긴 화살표

  static const LinearGradient metal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEDE2C8), // 반사광
      Color(0xFFD3BC8E),
      Color(0xFFA88A5C), // 짙은 놋쇠
      Color(0xFFC9AE7E),
      Color(0xFFE4D6B6), // 두 번째 반사광
      Color(0xFFB89A6A),
      Color(0xFF8E7148),
    ],
    stops: [0, 0.18, 0.38, 0.55, 0.64, 0.82, 1],
  );
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
