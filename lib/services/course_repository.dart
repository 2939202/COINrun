import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/official_courses.dart';
import '../models/course.dart';

// ============================================================
// 코스를 가져오는 곳
//
// 클래식 코스는 앱 안에 있고(official_courses.dart), 사설 코스는 Firestore의
// courses 컬렉션에서 읽습니다.
//
// [사설 코스 정렬]
//   "구가 같은 것 + 하트순"을 Firestore에서 한 번에 하려면 복합 색인을 따로
//   만들어야 합니다. 한 구의 코스는 많아야 수십 개라, 구로만 걸러 받은 뒤
//   하트순 정렬은 폰에서 합니다.
// ============================================================
class CourseRepository {
  CourseRepository._();

  static final CourseRepository instance = CourseRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Course> officialCourses(String district) =>
      OfficialCourses.inDistrict(district);

  // 하트를 많이 받은 순서. limit이 없으면 전부
  Stream<List<Course>> watchUserCourses(String district, {int? limit}) {
    return _firestore
        .collection('courses')
        .where('district', isEqualTo: district)
        .snapshots()
        .map((query) {
          final List<Course> courses =
              query.docs
                  .map((doc) => Course.fromMap(doc.id, doc.data()))
                  .where((course) => course.points.length >= 2)
                  .toList()
                ..sort((a, b) => b.hearts.compareTo(a.hearts));
          return limit == null ? courses : courses.take(limit).toList();
        });
  }
}
