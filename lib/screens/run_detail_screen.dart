import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../models/run_log.dart';
import '../models/run_route.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/route_map.dart';
import '../widgets/stat_block.dart';

// ============================================================
// 지난 러닝 기록 하나를 자세히 보는 화면
//
// 홈이나 전체 기록에서 한 줄을 누르면 들어옵니다.
// 숫자들은 목록에서 받아온 RunLog로 바로 그리고, 경로만 여기서 따로 읽어옵니다.
// (경로는 무거워서 목록에는 딸려오지 않습니다. models/run_route.dart 참고)
// ============================================================
class RunDetailScreen extends StatefulWidget {
  final String userId;
  final RunLog run;

  const RunDetailScreen({super.key, required this.userId, required this.run});

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
  // Future는 한 번만 만들어 둡니다. (build 안에서 만들면 다시 그릴 때마다 또 읽어옵니다)
  late final Future<RunRoute> _route = _load();

  Future<RunRoute> _load() {
    // 경로를 따로 두기 전에 저장된 기록은 기록 문서 안에 경로를 들고 있습니다.
    // 그런 기록은 더 읽어올 것이 없습니다.
    if (widget.run.legacyRoute.hasPath) {
      return Future.value(widget.run.legacyRoute);
    }
    return UserRepository.instance.loadRoute(widget.userId, widget.run.id);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final RunLog run = widget.run;
    final DateTime? date = run.createdAt;
    final Duration duration = Duration(seconds: run.durationSeconds);

    return Scaffold(
      appBar: AppBar(
        title: Text(date == null ? '러닝 기록' : formatMonthDay(date)),
      ),
      body: ListView(
        children: [
          // 어디를 뛰었는지
          SizedBox(height: 300, child: _buildMap()),

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

  Widget _buildMap() {
    return FutureBuilder<RunRoute>(
      future: _route,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: AppColors.cream,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }

        final RunRoute route = snapshot.data ?? RunRoute.empty;
        return Stack(
          children: [
            Positioned.fill(child: RouteMap(route: route)),

            // 개발 빌드에만 보입니다. 지도가 비어 있을 때, 저장된 점이 없는 것인지
            // 점은 있는데 안 그려지는 것인지 구분하려고 둡니다.
            if (kDebugMode)
              Positioned(
                left: AppSpacing.sm,
                top: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  color: AppColors.white,
                  child: Text(
                    '점 ${route.points.length}개 · 토막 ${route.segments.length}개'
                    '${widget.run.legacyRoute.hasPath ? " · 옛 기록" : ""}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 평균 페이스: 1km를 뛰는 데 걸린 시간(분). 거리가 거의 없으면 계산하지 않습니다.
  double? get _paceMinPerKm {
    final double km = widget.run.distanceMeters / 1000;
    if (km < 0.01) return null;
    return widget.run.durationSeconds / 60.0 / km;
  }
}
