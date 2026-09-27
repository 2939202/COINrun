import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

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
  // 경로 토막들. 신호가 오래 끊긴 구간은 토막이 나뉘어서, 실제로 지나지 않은 길을
  // 선으로 잇지 않습니다.
  final List<List<LatLng>> segments;

  // 경로 둘레에 남길 여백. 선이 화면 끝에 붙지 않게 합니다.
  final double padding;

  const RouteMap({super.key, required this.segments, this.padding = 28});

  // 지도 범위를 잡을 때는 토막을 신경 쓰지 않고 점만 씁니다.
  List<LatLng> get _points => [for (final segment in segments) ...segment];

  @override
  Widget build(BuildContext context) {
    // 선을 그릴 만한 토막이 하나도 없으면 (경로를 저장하기 전에 뛴 기록 포함)
    final List<List<LatLng>> drawable = [
      for (final segment in segments)
        if (segment.length >= 2) segment,
    ];
    if (drawable.isEmpty) return const _NoRoute();

    final List<LatLng> points = _points;

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
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.contact',
        ),
        PolylineLayer(
          polylines: [
            for (final segment in drawable)
              Polyline(points: segment, strokeWidth: 5, color: AppColors.black),
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
              child: const _EndDot(color: AppColors.volt, label: '도착'),
            ),
          ],
        ),
      ],
    );
  }
}

// 경로가 없을 때 (경로 저장을 붙이기 전에 뛴 기록)
class _NoRoute extends StatelessWidget {
  const _NoRoute();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.grey100,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        '이 기록에는 경로가 없어요.\n경로는 이번 업데이트부터 저장됩니다.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.grey500),
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
