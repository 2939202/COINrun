import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../game/honor_level.dart';
import '../game/official_courses.dart';
import '../game/route_simplifier.dart';
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
//
// [사설 코스 만들기]
//   "코스 만들기"로 한 번 달린 길을 그대로 코스로 올립니다. 점이 수천 개라
//   경로 솎아내기(Douglas-Peucker)로 줄여서 저장합니다.
//
// [하트]
//   courses/{id}/hearts/{uid} 문서가 있으면 그 사람이 하트를 누른 것입니다.
//   하트 수(hearts)는 정렬하려고 코스 문서에 따로 들고 있고, 누르고 뗄 때
//   트랜잭션으로 문서와 숫자를 같이 바꿉니다. 자기 코스에는 누를 수 없습니다.
// ============================================================
class CourseRepository {
  CourseRepository._();

  static final CourseRepository instance = CourseRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _courses =>
      _firestore.collection('courses');

  // 달린 길을 사설 코스로 저장하고, 만든 코스의 id를 돌려줍니다.
  Future<String> createUserCourse({
    required String userId,
    required String authorName,
    required String name,
    required String district,
    required List<List<LatLng>> segments,
  }) async {
    final List<LatLng> path = RouteSimplifier.simplify(
      Course.pathFromSegments(segments),
    );
    final Course course = Course(
      id: '',
      name: name,
      district: district,
      points: path,
      authorName: authorName,
      authorId: userId,
    );
    final doc = await _courses.add({
      ...course.toUserCourseMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // 내가 만든 사설 코스 수와 받은 하트 합 (명예 레벨)
  Stream<HonorLevel> watchHonor(String userId) => _courses
      .where('authorId', isEqualTo: userId)
      .snapshots()
      .map(
        (query) => HonorLevel(
          courses: query.docs.length,
          hearts: query.docs.fold(
            0,
            (total, doc) =>
                total + ((doc.data()['hearts'] as num?)?.toInt() ?? 0),
          ),
        ),
      );

  // 내가 이 코스에 하트를 눌렀는지
  Stream<bool> watchHearted(String courseId, String userId) => _courses
      .doc(courseId)
      .collection('hearts')
      .doc(userId)
      .snapshots()
      .map((doc) => doc.exists);

  // 하트 누르기/떼기
  Future<void> toggleHeart(String courseId, String userId) {
    final DocumentReference<Map<String, dynamic>> course = _courses.doc(
      courseId,
    );
    final DocumentReference<Map<String, dynamic>> heart = course
        .collection('hearts')
        .doc(userId);
    return _firestore.runTransaction((transaction) async {
      final mine = await transaction.get(heart);
      if (mine.exists) {
        transaction.delete(heart);
        transaction.update(course, {'hearts': FieldValue.increment(-1)});
      } else {
        transaction.set(heart, {'at': FieldValue.serverTimestamp()});
        transaction.update(course, {'hearts': FieldValue.increment(1)});
      }
    });
  }

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
