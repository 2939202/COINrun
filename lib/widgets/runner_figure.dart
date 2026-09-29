import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// 캐릭터 성별 프리셋. 커스터마이징을 붙이기 전까지 이 둘만 있습니다.
enum RunnerLook {
  female('assets/character/runner_female.png'),
  male('assets/character/runner_male.png');

  final String asset;

  const RunnerLook(this.asset);
}

// ============================================================
// 캐릭터 그림
//
// 지금은 기본 프리셋 그림을 그대로 보여줍니다. 장비를 갖춰 입은 모습이나
// 커스터마이징이 붙으면 이 위젯 안만 바꾸면 되도록 따로 빼두었습니다.
//
// 3D 모델(ModelViewer)을 쓰지 않는 이유: 그쪽은 내부적으로 웹뷰를 띄워서
// 홈 화면처럼 자주 열리는 곳에 두기에는 무겁습니다. 캐릭터 화면에서만 씁니다.
// ============================================================
class RunnerFigure extends StatelessWidget {
  final RunnerLook look;

  // 캐릭터가 서 있는 바닥 그림자를 그릴지
  final bool showGround;

  const RunnerFigure({
    super.key,
    this.look = RunnerLook.female,
    this.showGround = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = constraints.biggest.shortestSide;
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            if (showGround)
              Padding(
                padding: EdgeInsets.only(bottom: size * 0.02),
                child: Container(
                  width: size * 0.62,
                  height: size * 0.09,
                  decoration: const BoxDecoration(
                    color: AppColors.sand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Image.asset(
              look.asset,
              fit: BoxFit.contain,
              // 그림이 없으면 화면이 깨지지 않도록 빈 자리로 둡니다.
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}
