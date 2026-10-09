import 'package:latlong2/latlong.dart';

// ============================================================
// 러닝 코스 한 개
//
// [두 종류]
//   클래식 - 저희가 만들어 앱에 넣어 배포하는 공식 코스 (game/official_courses.dart)
//   사설   - 유저가 만들어 공유하는 코스. Firestore의 courses 컬렉션에 있고,
//            하트를 많이 받은 순서로 보여줍니다.
//
// 코스는 "구" 단위로 묶습니다. 코스 화면은 지금 있는 구의 코스를 먼저 보여줍니다.
// ============================================================
class Course {
  final String id;
  final String name;
  final String district; // 서울의 구 이름 (예: 노원구)
  final List<LatLng> points; // 출발 -> 도착 순서
  final bool official;
  final int hearts; // 사설 코스만 씁니다
  final String? authorName; // 사설 코스를 만든 사람
  final String? authorId; // 만든 사람의 uid. 자기 코스에는 하트를 못 누릅니다.

  const Course({
    required this.id,
    required this.name,
    required this.district,
    required this.points,
    this.official = false,
    this.hearts = 0,
    this.authorName,
    this.authorId,
  });

  // 사설 코스로 저장할 수 있는 최소 거리
  static const double minUserCourseKm = 0.5;

  // 달린 기록(토막 여럿) -> 코스 한 줄. 토막 사이 끊긴 구간은 그냥 이어 붙입니다.
  // 코스는 한 줄로 따라가는 길이라, 신호가 잠깐 끊겼어도 이어서 보는 편이 자연스럽습니다.
  static List<LatLng> pathFromSegments(List<List<LatLng>> segments) => [
    for (final segment in segments) ...segment,
  ];

  Map<String, dynamic> toUserCourseMap() => {
    'name': name,
    'district': district,
    'points': [
      for (final p in points) {'lat': p.latitude, 'lng': p.longitude},
    ],
    'hearts': hearts,
    'authorName': authorName,
    'authorId': authorId,
  };

  static const Distance _distance = Distance();

  // 코스 길이 (m). 점이 수십 개라 그때그때 계산해도 가볍습니다.
  double get distanceMeters {
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += _distance(points[i - 1], points[i]);
    }
    return total;
  }

  // Firestore courses/{id} 문서 -> 사설 코스
  //   points는 [{lat, lng}, ...] 로 저장합니다. (Firestore는 배열 안에 배열을 못 넣습니다)
  factory Course.fromMap(String id, Map<String, dynamic> map) {
    final List<dynamic> raw = map['points'] as List<dynamic>? ?? const [];
    return Course(
      id: id,
      name: map['name'] as String? ?? '이름 없는 코스',
      district: map['district'] as String? ?? '',
      points: [
        for (final p in raw.whereType<Map<String, dynamic>>())
          LatLng(
            (p['lat'] as num?)?.toDouble() ?? 0,
            (p['lng'] as num?)?.toDouble() ?? 0,
          ),
      ],
      hearts: (map['hearts'] as num?)?.toInt() ?? 0,
      authorName: map['authorName'] as String?,
      authorId: map['authorId'] as String?,
    );
  }
}
