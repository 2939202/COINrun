import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/app_theme.dart';

// ============================================================
// 지도 바탕 그림 (타일)
//
// [왜 기본 OpenStreetMap 타일을 쓰지 않나]
//   기본 타일은 공원이 초록, 큰길이 노랑·주황으로 칠해져 있습니다. 색이 많아서
//   우리 화면(먹색 + 크림)에 얹으면 지도만 혼자 튀고, 그 위에 그린 경로선도 묻힙니다.
//
//   CARTO의 Positron은 회색과 흰색만 쓰는 바탕지도입니다. 길과 글자만 남아 있어서
//   경로선이 또렷하게 보입니다. 열쇠(API key) 없이 쓸 수 있습니다.
//
// [따뜻하게 물들이기]
//   Positron은 차가운 회색이라 크림색 화면과 나란히 두면 파랗게 떠 보입니다.
//   크림색을 곱해서(modulate) 아주 살짝 노르스름하게 만듭니다. 흰 곳은 크림이 되고
//   회색 길은 따뜻한 회색이 됩니다.
//
// [출처 표시]
//   CARTO와 OpenStreetMap 모두 지도에 출처를 적어두기를 요구합니다.
//   지도를 쓰는 곳마다 attribution을 같이 넣어야 합니다.
// ============================================================
class MapTiles {
  MapTiles._();

  static const String _positron =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

  static const String attributionText = '© OpenStreetMap · © CARTO';

  // 지도 바탕. FlutterMap의 children 맨 앞에 넣습니다.
  static Widget layer() {
    return ColorFiltered(
      // 크림색을 곱해서 차가운 회색을 따뜻하게 바꿉니다.
      colorFilter: const ColorFilter.mode(AppColors.cream, BlendMode.modulate),
      child: TileLayer(
        urlTemplate: _positron,
        subdomains: const ['a', 'b', 'c', 'd'],
        userAgentPackageName: 'com.example.contact',
      ),
    );
  }

  // 출처 표시. FlutterMap의 children 맨 뒤에 넣습니다.
  static Widget attribution() {
    return const SimpleAttributionWidget(
      source: Text(attributionText, style: TextStyle(fontSize: 10)),
      backgroundColor: Color(0xCCFFFFFF),
    );
  }
}
