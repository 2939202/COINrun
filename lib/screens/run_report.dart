import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../game/run_load.dart';
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
//
// 돌려주는 값: 부하도 띠에서 고른 단계. 아무것도 안 눌렀으면 계산값 그대로입니다.
Future<int> showRunReport(
  BuildContext context,
  RunRecord record,
  RunReward reward,
  RunLoad load,
) async {
  // 화면이 다시 그려져도 진동 횟수 제한이 처음부터 다시 세지지 않게 여기서 한 번만 만듭니다.
  final _CoinBuzzer buzzer = _CoinBuzzer();
  final ValueNotifier<int> chosen = ValueNotifier(load.level);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '러닝 완료',
    // 막은 투명하게 두고, 흐림 효과를 우리가 직접 깝니다.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => _RunReport(
      record: record,
      reward: reward,
      load: load,
      chosen: chosen,
      buzzer: buzzer,
    ),
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
  final int level = chosen.value;
  chosen.dispose();
  return level;
}

class _RunReport extends StatelessWidget {
  final RunRecord record;
  final RunReward reward;
  final RunLoad load;
  final ValueNotifier<int> chosen;
  final _CoinBuzzer buzzer;

  const _RunReport({
    required this.record,
    required this.reward,
    required this.load,
    required this.chosen,
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
          // 화면에 다 들어가면 가운데, 설명을 펼치거나 레벨업 문구가 붙어 넘치면 스크롤됩니다.
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.lg * 2,
                  ),
                  child: Center(
                    child: Container(
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
                  ),
                ),
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
    // 창 안의 것은 전부 가운데 맞춤입니다.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('러닝 완료', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        _LoadScale(load: load, chosen: chosen),
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

// 부하도 띠. 가전제품 에너지 효율 등급표처럼 1~5칸을 늘어놓고 고른 단계만 크게.
// 1은 거의 흰색, 올라갈수록 짙어져서 5는 구릿빛입니다.
//
// 처음에는 공식으로 계산한 단계가 골라져 있습니다. 그대로 두면 끝입니다.
// 내가 느낀 것과 다르면 다른 칸을 누르면 되고, 위에 그 단계의 설명이 열립니다.
// 확인으로 창을 닫으면 고른 단계가 기록에 저장됩니다. (계산값도 따로 남습니다)
class _LoadScale extends StatefulWidget {
  final RunLoad load;
  final ValueNotifier<int> chosen;

  const _LoadScale({required this.load, required this.chosen});

  static const List<Color> colors = [
    Color(0xFFF4EFE7), // 1 하얀 쪽
    Color(0xFFE6D2B8),
    Color(0xFFCFA97E),
    Color(0xFFB0774A),
    Color(0xFF8A4A26), // 5 구리
  ];

  // 단계마다 몸으로 느끼는 정도. 고를 때 기준이 됩니다.
  static const List<String> feels = [
    '숨이 차지 않는 산책이나 아주 가벼운 조깅입니다.',
    '대화를 나누며 달릴 수 있는 정도입니다.',
    '숨이 조금 차지만 계속 달릴 수 있는 정도입니다.',
    '말을 이어 가기 힘들 만큼 숨이 찬 정도입니다.',
    '끝나고 한동안 쉬어야 할 만큼 힘든 정도입니다.',
  ];

  // 밝은 칸에는 검은 글자, 짙은 칸에는 흰 글자
  static Color inkOn(int level) =>
      level >= 4 ? AppColors.white : AppColors.black;

  @override
  State<_LoadScale> createState() => _LoadScaleState();
}

class _LoadScaleState extends State<_LoadScale> {
  bool _open = false;

  int get _level => widget.chosen.value;

  void _pick(int level) {
    setState(() {
      // 같은 칸을 다시 누르면 설명만 접고 펼칩니다.
      _open = level == _level ? !_open : true;
      widget.chosen.value = level;
    });
  }

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final RunLoad load = widget.load;
    final int level = _level;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 설명은 띠 위에 열립니다.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                  child: _LoadExplanation(
                    load: load,
                    level: level,
                    onClose: _toggle,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int l = 1; l <= 5; l++)
              GestureDetector(
                onTap: () => _pick(l),
                behavior: HitTestBehavior.opaque,
                // 칸 사이 틈까지 누를 수 있게 둘레를 넉넉히 잡습니다.
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2.5,
                    vertical: 4,
                  ),
                  child: _chip(l, l == level, l == load.level),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '부하도 $level · ${RunLoad.labels[level - 1]}',
                style: AppTheme.sans.copyWith(
                  fontSize: 13,
                  fontWeight: AppTheme.sansMedium,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _open ? Icons.expand_less : Icons.info_outline,
                size: 15,
                color: AppColors.label,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          level == load.level
              ? '내가 느낀 것과 다르면 칸을 눌러 바꿀 수 있습니다'
              : '계산값은 ${load.level} · 확인을 누르면 $level로 저장됩니다',
          style: AppTheme.sans.copyWith(fontSize: 11, color: AppColors.label),
        ),
      ],
    );
  }

  // current: 지금 고른 칸(크게), computed: 공식으로 계산한 칸(아래에 점)
  Widget _chip(int level, bool current, bool computed) {
    final double w = current ? 42 : 30;
    final double h = current ? 32 : 21;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: w,
          height: h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _LoadScale.colors[level - 1],
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: current ? AppColors.black : AppColors.sand,
              width: current ? 1.8 : 1,
            ),
          ),
          child: Text(
            '$level',
            style: AppTheme.number.copyWith(
              fontSize: current ? 18 : 12,
              color: _LoadScale.inkOn(level),
            ),
          ),
        ),
        const SizedBox(height: 3),
        // 계산값 자리 표시. 고른 값과 달라도 계산값이 어디였는지 보이게 합니다.
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: computed ? AppColors.black : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// 띠 위에 열리는 설명: 고른 단계가 어떤 느낌인지 + 공식으로 계산한 근거
class _LoadExplanation extends StatelessWidget {
  final RunLoad load;
  final int level;
  final VoidCallback onClose;

  const _LoadExplanation({
    required this.load,
    required this.level,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle body = AppTheme.sans.copyWith(
      fontSize: 12.5,
      height: 1.5,
      color: AppColors.black,
    );
    final TextStyle sub = body.copyWith(color: AppColors.label, fontSize: 11.5);
    final String basis = load.thresholdFromRuns == 0
        ? '아직 기록이 적어 입문 기준'
        : '최근 ${load.thresholdFromRuns}번의 러닝으로 추정';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md - 2,
        AppSpacing.sm + 2,
        AppSpacing.xs,
        AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$level · ${RunLoad.labels[level - 1]}',
                  style: AppTheme.serifNumber.copyWith(
                    fontSize: 14,
                    height: 1.3,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_LoadScale.feels[level - 1], style: body),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '계산값 ${load.level} · ${load.label}',
                  style: body.copyWith(fontWeight: AppTheme.sansMedium),
                ),
                Text(
                  '역치 페이스 ${formatPace(load.thresholdPace)} ($basis)\n'
                  '강도 ${load.intensity.toStringAsFixed(2)}² × '
                  '움직인 시간 ${load.movingMinutes}분 → '
                  '부하 ${load.load.round()}'
                  '${load.walk ? '\n분당 걸음이 적어 걷기로 보고 강도를 낮췄습니다.' : ''}',
                  style: body,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '역치 페이스로 1시간 = 100\n'
                  '1 ~25 · 2 ~50 · 3 ~80 · 4 ~120 · 5 120+',
                  style: sub,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '닫기',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18, color: AppColors.label),
          ),
        ],
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
