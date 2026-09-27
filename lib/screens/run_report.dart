import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../game/run_rules.dart';
import '../models/run_record.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/route_map.dart';
import '../widgets/stat_block.dart';

// ============================================================
// 러닝 완료 리포트
//
// 뒤에 있는 러닝 화면의 지도를 가우시안 블러로 흐리게 덮고, 그 위에
// 이번에 뛴 영역만 딱 맞게 잘라낸 지도를 새로 보여줍니다.
//
// showModalBottomSheet를 쓰지 않는 이유
//   기본 바텀시트는 뒤를 흐리게 만들 수 없습니다. 어두운 막만 씌울 수 있어서
//   지도가 그대로 비쳐 보입니다. showGeneralDialog로 직접 만들면 BackdropFilter를
//   화면 전체에 깔 수 있습니다.
// ============================================================
Future<void> showRunReport(
  BuildContext context,
  RunRecord record,
  RunReward reward,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '러닝 완료',
    // 막은 투명하게 두고, 흐림 효과를 우리가 직접 깝니다.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) =>
        _RunReport(record: record, reward: reward),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        // 카드가 아래에서 살짝 올라옵니다.
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _RunReport extends StatelessWidget {
  final RunRecord record;
  final RunReward reward;

  const _RunReport({required this.record, required this.reward});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 뒤에 있는 러닝 화면 지도를 흐리게 덮습니다.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              // 흐리게만 하면 글자가 잘 안 읽혀서 흰 막을 옅게 겹칩니다.
              child: Container(color: AppColors.white.withValues(alpha: 0.6)),
            ),
          ),

          // 2. 리포트
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 이번에 뛴 영역만 잘라낸 지도
                        SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: RouteMap(path: record.path),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: _buildBody(context, textTheme),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('러닝 완료', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            StatBlock(value: formatKm(record.distanceMeters), label: '킬로미터'),
            StatBlock(
              value: formatDuration(record.movingTime),
              label: '움직인 시간',
            ),
            StatBlock(value: '${record.steps}', label: '걸음'),
          ],
        ),
        if (record.stepsEstimated) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '* 걸음 센서를 쓸 수 없어서 거리로 추정한 걸음 수예요.',
            style: textTheme.labelMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            StatBlock(value: '+${reward.gold}', label: '골드'),
            StatBlock(value: '+${reward.exp}', label: '경험치'),
            StatBlock(value: 'Lv.${reward.levelAfter}', label: '레벨'),
          ],
        ),
        if (reward.leveledUp) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.volt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '레벨 업! Lv.${reward.levelAfter} · '
              '${RunRules.tierName(reward.levelAfter)}',
              style: textTheme.titleMedium,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ),
      ],
    );
  }
}
