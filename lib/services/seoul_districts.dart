import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

// ============================================================
// 서울 25개 구의 경계선
//
// 지금 위치가 어느 구인지 알아내는 데 씁니다. 경계선을 앱에 넣어두고(assets/geo)
// 점이 어느 다각형 안에 있는지 직접 계산합니다.
//
// [왜 폰의 주소 변환(역지오코딩)을 쓰지 않나]
//   인터넷이 있어야 하고, 기종마다 "노원구"가 들어오는 칸이 달라서 믿기 어렵습니다.
//   경계선은 30KB도 안 되고 인터넷 없이 바로 답이 나옵니다.
//
// 경계는 통계청 2013년 자료(github.com/southkorea/seoul-maps)를 단순화한 것이라
// 구 경계 바로 위에서는 몇십 m 틀릴 수 있습니다. 코스를 고르는 데는 충분합니다.
// ============================================================
class SeoulDistricts {
  final Map<String, List<LatLng>> _polygons;

  SeoulDistricts._(this._polygons);

  static const String assetPath = 'assets/geo/seoul_districts.json';

  static Future<SeoulDistricts>? _loading;

  // 처음 한 번만 읽고 이후에는 같은 것을 돌려줍니다.
  static Future<SeoulDistricts> load() {
    return _loading ??= rootBundle
        .loadString(assetPath)
        .then(SeoulDistricts.parse);
  }

  // 파일 내용 -> 경계선. 테스트에서는 파일을 직접 읽어 이걸 부릅니다.
  static SeoulDistricts parse(String json) {
    final Map<String, dynamic> root = jsonDecode(json) as Map<String, dynamic>;
    final Map<String, dynamic> districts =
        root['districts'] as Map<String, dynamic>;
    return SeoulDistricts._({
      for (final entry in districts.entries)
        entry.key: [
          for (final p in entry.value as List<dynamic>)
            LatLng(
              ((p as List<dynamic>)[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ),
        ],
    });
  }

  // 가나다순 구 이름 (검색 목록)
  List<String> get names => _polygons.keys.toList()..sort();

  // 이 위치가 속한 구. 서울 밖이면 null
  String? districtAt(LatLng point) {
    for (final entry in _polygons.entries) {
      if (_contains(entry.value, point)) return entry.key;
    }
    return null;
  }

  // "노원" -> 노원구. 이름 일부만 쳐도 찾습니다.
  List<String> search(String query) {
    final String q = query.trim();
    if (q.isEmpty) return names;
    return names.where((name) => name.contains(q)).toList();
  }

  // 점에서 오른쪽으로 반직선을 그었을 때 경계를 홀수 번 넘으면 안쪽입니다.
  static bool _contains(List<LatLng> polygon, LatLng point) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final LatLng a = polygon[i];
      final LatLng b = polygon[j];
      final bool crosses =
          (a.latitude > point.latitude) != (b.latitude > point.latitude);
      if (!crosses) continue;
      final double xAtPoint =
          a.longitude +
          (point.latitude - a.latitude) /
              (b.latitude - a.latitude) *
              (b.longitude - a.longitude);
      if (point.longitude < xAtPoint) inside = !inside;
    }
    return inside;
  }
}
