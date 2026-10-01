import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// 골드 아이콘. 금테 두른 동전 안에 G가 찍혀 있습니다.
// 골드 숫자 옆에는 "G" 글자 대신 이걸 붙입니다.
class GoldCoin extends StatelessWidget {
  final double size;

  const GoldCoin({super.key, this.size = 17});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cream,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: size * 0.077),
      ),
      child: Text(
        'G',
        style: AppTheme.number.copyWith(
          fontSize: size * 0.53,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
