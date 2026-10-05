import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/run_route.dart';
import '../theme/app_theme.dart';
import 'map_tiles.dart';

// ============================================================
// 다 뛴 뒤에 경로만 보여주는 작은 지도
//
// 러닝 화면의 지도와 다른 점
//   - 따라다니지 않습니다. 뛴 영역에 딱 맞게 한 번 맞춰놓고 그대로 둡니다.
//   - 손으로 움직이거나 확대할 수 없습니다. (그림처럼 보이기만 합니다)
//   - 시작점과 끝점에 표시를 찍어서 어느 쪽으로 돌았는지 알 수 있게 합니다.
//
// 완료 리포트와 기록 상세 화면에서 같이 씁니다.
// ============================================================
class RouteMap extends StatelessWidget {
  final RunRoute route;

  // 경로 둘레에 남길 여백. 선이 화면 끝에 붙지 않게 합니다.
  final double padding;

  const RouteMap({super.key, required this.route, this.padding = 28});

  @override
  Widget build(BuildContext context) {
    // 선을 그릴 만한 토막이 하나도 없으면 (경로를 저장하기 전에 뛴 기록 포함)
    final List<List<LatLng>> drawable = [
      for (final segment in route.segments)
        if (segment.length >= 2) segment,
    ];
    if (drawable.isEmpty) return const _NoRoute();

    final List<LatLng> points = route.points;

    return FlutterMap(
      options: MapOptions(
        // 뛴 영역 전체가 화면에 들어오도록 확대/위치를 자동으로 맞춥니다.
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: EdgeInsets.all(padding),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        ...MapTiles.layers(),
        PolylineLayer(
          polylines: [
            for (final segment in drawable)
              Polyline(
                points: segment,
                strokeWidth: 3.5,
                // 러닝 화면과 같은 선: 먹색에 얇은 흰 테두리
                color: AppColors.black,
                borderStrokeWidth: 1.5,
                borderColor: AppColors.white,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: points.first,
              width: 18,
              height: 18,
              child: const _EndDot(color: AppColors.white, label: '출발'),
            ),
            Marker(
              point: points.last,
              width: 18,
              height: 18,
              child: const _EndDot(color: AppColors.accent, label: '도착'),
            ),
          ],
        ),
        MapTiles.attribution(),
      ],
    );
  }
}

// 경로가 없을 때 (경로 저장을 붙이기 전에 뛴 기록, 움직이지 않고 끝낸 기록)
class _NoRoute extends StatelessWidget {
  const _NoRoute();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        '이 기록에는 지나온 길이 남아 있지 않아요.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.mute),
      ),
    );
  }
}

// 출발점/도착점 표시
class _EndDot extends StatelessWidget {
  final Color color;
  final String label;

  const _EndDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.black, width: 3),
        ),
      ),
    );
  }
}
