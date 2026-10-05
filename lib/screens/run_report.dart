import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../game/run_grade.dart';
import '../game/run_rules.dart';
import '../models/run_record.dart';
import '../models/run_route.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/coin_rain.dart';
import '../widgets/route_map.dart';

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
  // 화면이 다시 그려져도 진동 횟수 제한이 처음부터 다시 세지지 않게 여기서 한 번만 만듭니다.
  final _CoinBuzzer buzzer = _CoinBuzzer();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '러닝 완료',
    // 막은 투명하게 두고, 흐림 효과를 우리가 직접 깝니다.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) =>
        _RunReport(record: record, reward: reward, buzzer: buzzer),
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
  final _CoinBuzzer buzzer;

  const _RunReport({
    required this.record,
    required this.reward,
    required this.buzzer,
  });

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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 이번에 뛴 영역만 잘라낸 지도
                        SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: RouteMap(route: RunRoute(record.segments)),
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

          // 3. 받은 골드만큼 금화가 쏟아져서 화면 바닥에 통통 튑니다.
          Positioned.fill(
            child: CoinRain(gold: reward.gold, onImpact: buzzer.buzz),
          ),
        ],
      ),
    );
  }

  // 위에서부터: 제목 -> 등급(가운데, 작게) -> 숫자 두 줄 -> 레벨업 -> 확인
  //   1줄: 킬로미터 · 평균 페이스 · 움직인 시간   (얼마나 달렸나)
  //   2줄: 골드 · 경험치 · 칼로리 · 걸음          (무엇을 얻었나)
  Widget _buildBody(BuildContext context, TextTheme textTheme) {
    final int grade = RunGrade.of(record);
    // 창 안의 것은 전부 가운데 맞춤입니다.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('러닝 완료', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        _GradeScale(grade: grade),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _Cell(value: formatKm(record.distanceMeters), label: '킬로미터'),
            _Cell(value: formatPace(record.paceMinPerKm), label: '평균 페이스'),
            _Cell(value: formatDuration(record.movingTime), label: '움직인 시간'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Row(
          children: [
            _Cell(value: '+${reward.gold}', label: '골드'),
            _Cell(value: '+${reward.exp}', label: '경험치'),
            _Cell(value: '${record.calories.round()}', label: 'kcal'),
            _Cell(
              value: '${record.steps}',
              label: record.stepsEstimated ? '걸음 (추정)' : '걸음',
            ),
          ],
        ),
        if (reward.leveledUp) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '레벨 업! Lv.${reward.levelAfter} · '
              '${RunRules.tierName(reward.levelAfter)}',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: AppColors.white),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
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

// 작은 숫자 한 칸: 위에 값, 아래에 이름. 칸 안에서 가운데 맞춤
class _Cell extends StatelessWidget {
  final String value;
  final String label;

  const _Cell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppTheme.number.copyWith(fontSize: 18)),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans.copyWith(fontSize: 11, color: AppColors.label),
          ),
        ],
      ),
    );
  }
}

// 러닝 등급 띠. 가전제품 에너지 효율 등급표처럼 1~5칸을 늘어놓고 이번 등급만 크게.
// 1은 거의 흰색, 올라갈수록 짙어져서 5는 구릿빛입니다.
class _GradeScale extends StatelessWidget {
  final int grade;

  const _GradeScale({required this.grade});

  static const List<Color> colors = [
    Color(0xFFF4EFE7), // 1 하얀 쪽
    Color(0xFFE6D2B8),
    Color(0xFFCFA97E),
    Color(0xFFB0774A),
    Color(0xFF8A4A26), // 5 구리
  ];

  // 밝은 칸에는 검은 글자, 짙은 칸에는 흰 글자
  static Color inkOn(int g) => g >= 4 ? AppColors.white : AppColors.black;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int g = 1; g <= 5; g++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _chip(g, g == grade),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          '러닝 등급 $grade · ${RunGrade.verdict(grade)}',
          style: AppTheme.sans.copyWith(
            fontSize: 12,
            fontWeight: AppTheme.sansMedium,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }

  Widget _chip(int g, bool current) {
    final double w = current ? 34 : 24;
    final double h = current ? 26 : 16;
    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors[g - 1],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: current ? AppColors.black : AppColors.sand,
          width: current ? 1.6 : 1,
        ),
      ),
      child: Text(
        '$g',
        style: AppTheme.number.copyWith(
          fontSize: current ? 15 : 10,
          color: inkOn(g),
        ),
      ),
    );
  }
}

// 금화가 바닥에 닿을 때마다 짧게 "톡" 떨립니다.
//
// 금화가 수십 개라 닿을 때마다 다 떨면 진동이 뭉개져 "징—" 하고 길게만 느껴집니다.
// 그래서 70ms에 한 번까지만, 전부 합쳐 24번까지만 떱니다.
class _CoinBuzzer {
  static const Duration gap = Duration(milliseconds: 70);
  static const int maxBuzzes = 24;

  final Stopwatch _clock = Stopwatch()..start();
  Duration? _lastAt;
  int _count = 0;
  bool? _hasVibrator;

  Future<void> buzz() async {
    final Duration now = _clock.elapsed;
    if (_count >= maxBuzzes) return;
    if (_lastAt != null && now - _lastAt! < gap) return;
    _lastAt = now;
    _count++;
    try {
      _hasVibrator ??= await Vibration.hasVibrator();
      if (_hasVibrator != true) return;
      // 첫 금화는 조금 세게, 나머지는 가볍게
      await Vibration.vibrate(
        duration: _count == 1 ? 45 : 18,
        amplitude: _count == 1 ? 200 : 90,
      );
    } catch (_) {
      // 진동이 없는 기기(웹 등)는 그냥 넘어갑니다.
    }
  }
}
