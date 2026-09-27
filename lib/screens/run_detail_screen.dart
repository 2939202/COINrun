import 'package:flutter/material.dart';

import '../models/run_log.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/route_map.dart';
import '../widgets/stat_block.dart';

// ============================================================
// 지난 러닝 기록 하나를 자세히 보는 화면
//
// 홈의 "최근 러닝" 줄을 누르면 들어옵니다.
// 목록에서 받아온 RunLog 하나로 전부 그리기 때문에 따로 더 읽어오지 않습니다.
// ============================================================
class RunDetailScreen extends StatelessWidget {
  final RunLog run;

  const RunDetailScreen({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final DateTime? date = run.createdAt;
    final Duration duration = Duration(seconds: run.durationSeconds);

    return Scaffold(
      appBar: AppBar(title: Text(date == null ? '러닝 기록' : formatMonthDay(date))),
      body: ListView(
        children: [
          // 어디를 뛰었는지
          SizedBox(height: 300, child: RouteMap(path: run.path)),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 메인 숫자: 거리
                Text(
                  formatKm(run.distanceMeters),
                  style: textTheme.displayLarge,
                ),
                Text('킬로미터', style: textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xl),

                Row(
                  children: [
                    StatBlock(
                      value: formatDuration(duration),
                      label: '시간',
                      alignment: CrossAxisAlignment.start,
                    ),
                    StatBlock(
                      value: formatPace(_paceMinPerKm),
                      label: '평균 페이스',
                      alignment: CrossAxisAlignment.start,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(),
                const SizedBox(height: AppSpacing.lg),

                Text('이 러닝으로 얻은 것', style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    StatBlock(
                      value: '+${run.goldEarned}',
                      label: '골드',
                      alignment: CrossAxisAlignment.start,
                    ),
                    StatBlock(
                      value: '+${run.expEarned}',
                      label: '경험치',
                      alignment: CrossAxisAlignment.start,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 평균 페이스: 1km를 뛰는 데 걸린 시간(분). 거리가 거의 없으면 계산하지 않습니다.
  double? get _paceMinPerKm {
    final double km = run.distanceMeters / 1000;
    if (km < 0.01) return null;
    return run.durationSeconds / 60.0 / km;
  }
}
