import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/app_theme.dart';

// ============================================================
// 지도 바탕 그림 (타일)
//
// [왜 기본 OpenStreetMap 타일을 쓰지 않나]
//   기본 타일은 공원이 초록, 큰길이 노랑·주황으로 칠해져 있습니다. 색이 많아서
//   우리 화면(먹색 + 크림)에 얹으면 지도만 혼자 튀고, 그 위의 경로선도 묻힙니다.
//
// [CARTO Positron을 쓰지 않는 이유]
//   회색만 쓰는 깔끔한 지도라 처음에 골랐는데, 이제 열쇠(API key) 없이 받으면
//   "key required"라고 적힌 안내 그림만 내려옵니다. 지도가 아예 안 보입니다.
//
// [Esri World Light Gray]
//   회색과 흰색만 쓰는 바탕지도입니다. 열쇠 없이 받을 수 있고, 실제로 타일을 받아서
//   확인했습니다. 길 모양만 남아 있어서 그 위의 경로선이 또렷합니다.
//
//   바탕과 지명이 따로 내려옵니다. 지명을 빼면 더 조용하지만 어디인지 알기 어려워서
//   둘 다 얹습니다. 다만 지명이 영어로 나옵니다. (Yongsan-Gu)
//
// [따뜻하게 물들이기]
//   바탕이 차가운 회색이라 크림색 화면과 나란히 두면 파랗게 떠 보입니다.
//   크림색을 곱해서(modulate) 종이색 쪽으로 당깁니다. 지명은 건드리지 않습니다.
//
// [출처 표시]
//   Esri는 지도에 출처를 적어두기를 요구합니다. 지도를 쓰는 곳마다 같이 넣어야 해서
//   타일과 한 파일에 묶어둡니다.
// ============================================================
class MapTiles {
  MapTiles._();

  static const String _base =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/'
      'World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';

  static const String _labels =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/'
      'World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}';

  static const String attributionText = '© Esri · © OpenStreetMap';

  static const String _userAgent = 'com.example.contact';

  // 지도 바탕. FlutterMap의 children 맨 앞에 펼쳐서(...) 넣습니다.
  static List<Widget> layers() {
    return [
      ColorFiltered(
        // 크림색을 곱해서 차가운 회색을 따뜻하게 바꿉니다.
        colorFilter: const ColorFilter.mode(
          AppColors.cream,
          BlendMode.modulate,
        ),
        child: TileLayer(urlTemplate: _base, userAgentPackageName: _userAgent),
      ),
      // 지명은 물들이지 않습니다. 흐려지면 읽기 어려워집니다.
      TileLayer(urlTemplate: _labels, userAgentPackageName: _userAgent),
    ];
  }

  // 출처 표시. FlutterMap의 children 맨 뒤에 넣습니다.
  static Widget attribution() {
    return const SimpleAttributionWidget(
      source: Text(attributionText, style: TextStyle(fontSize: 10)),
      backgroundColor: Color(0xCCFFFFFF),
    );
  }
}
