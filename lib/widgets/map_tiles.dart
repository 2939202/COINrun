import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/app_theme.dart';

// ============================================================
// 지도 바탕 그림 (타일)
//
// [고르면서 겪은 것]
//   CARTO Positron - 회색만 쓰는 깔끔한 지도인데, 이제 열쇠(API key) 없이 받으면
//     "key required" 안내 그림만 내려옵니다.
//   Esri World Light Gray - 열쇠는 필요 없지만 z14부터 "Map data not yet available"
//     입니다. 러닝은 z17쯤에서 봐야 해서 쓸 수 없습니다.
//   OpenStreetMap 기본 - z17에서도 잘 나오고 지명도 한글입니다. 대신 공원이 초록,
//     큰길이 노랑·주황이라 색이 많습니다.
//
//   그래서 OpenStreetMap을 쓰되, 색을 빼서 조용하게 만듭니다.
//
// [어떻게 조용하게 만드나]
//   1. 채도를 22%만 남깁니다. 초록 공원과 노란 길이 따뜻한 회색이 됩니다.
//      글자는 원래 검은색이라 그대로 읽힙니다.
//   2. 크림색을 곱해서 종이색 쪽으로 당깁니다.
//
//   색이 빠지면 그 위에 그린 경로선만 또렷하게 남습니다.
//
// [출처 표시]
//   지도 위에는 출처를 띄우지 않고, 설정 > 지도 및 데이터 출처에 모아 둡니다.
//   (screens/settings_screen.dart의 출처 목록이 attributionText를 씁니다)
// ============================================================
class MapTiles {
  MapTiles._();

  static const String _url = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String attributionText = '© OpenStreetMap contributors';

  static const String userAgent = 'app.dalirang.rpg';

  // 채도를 낮추는 행렬. 마지막 줄은 투명도라 건드리지 않습니다.
  static const List<double> _desaturate = <double>[
    0.3858,
    0.5579,
    0.0563,
    0.0000,
    0.0000,
    0.1658,
    0.7779,
    0.0563,
    0.0000,
    0.0000,
    0.1658,
    0.5579,
    0.2763,
    0.0000,
    0.0000,
    0.0000,
    0.0000,
    0.0000,
    1.0000,
    0.0000,
  ];

  // 지도 바탕. FlutterMap의 children 맨 앞에 펼쳐서(...) 넣습니다.
  static List<Widget> layers() {
    return [
      ColorFiltered(
        // 2) 종이색 쪽으로
        colorFilter: const ColorFilter.mode(
          AppColors.cream,
          BlendMode.modulate,
        ),
        child: ColorFiltered(
          // 1) 색 빼기
          colorFilter: const ColorFilter.matrix(_desaturate),
          child: TileLayer(
            urlTemplate: _url,
            // OpenStreetMap은 요청한 앱을 이 이름으로 구분합니다. Flutter 기본값인
            // com.example.*은 막히는 일이 있어서 이 앱만의 이름을 씁니다.
            // (앱 패키지 이름과는 상관없습니다)
            userAgentPackageName: userAgent,
          ),
        ),
      ),
    ];
  }
}
