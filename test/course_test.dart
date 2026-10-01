import 'dart:io';

import 'package:contact/game/official_courses.dart';
import 'package:contact/models/course.dart';
import 'package:contact/services/seoul_districts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('지금 위치의 구 찾기', () {
    final districts = SeoulDistricts.parse(
      File(SeoulDistricts.assetPath).readAsStringSync(),
    );

    test('서울 25개 구가 다 있다', () {
      expect(districts.names.length, 25);
    });

    test('한국성서대학교는 노원구', () {
      expect(districts.districtAt(const LatLng(37.64866, 127.06421)), '노원구');
    });

    test('명동은 중구, 코엑스는 강남구', () {
      expect(districts.districtAt(const LatLng(37.5636, 126.9850)), '중구');
      expect(districts.districtAt(const LatLng(37.5116, 127.0595)), '강남구');
    });

    test('서울 밖이면 null', () {
      // 부산
      expect(districts.districtAt(const LatLng(35.1796, 129.0756)), isNull);
    });

    test('이름 일부로 검색된다', () {
      expect(districts.search('노원'), ['노원구']);
      expect(districts.search('').length, 25);
    });
  });

  group('클래식 코스', () {
    test('모든 클래식 코스는 실제 구 이름에 들어 있다', () {
      final names = SeoulDistricts.parse(
        File(SeoulDistricts.assetPath).readAsStringSync(),
      ).names;
      for (final course in OfficialCourses.all) {
        expect(names, contains(course.district), reason: course.name);
        expect(course.official, isTrue);
      }
    });

    test('당현천 코스 길이가 그럴듯하다', () {
      final full = OfficialCourses.all.firstWhere(
        (c) => c.id == 'official-danghyeon-full',
      );
      final roundTrip = OfficialCourses.all.firstWhere(
        (c) => c.id == 'official-danghyeon-kbu',
      );
      expect(full.distanceMeters, closeTo(2890, 60));
      expect(roundTrip.distanceMeters, closeTo(2720, 60));
      // 왕복이라 출발과 도착이 같은 자리
      expect(roundTrip.points.first, roundTrip.points.last);
    });

    test('노원구에만 있다', () {
      expect(OfficialCourses.inDistrict('노원구').length, 2);
      expect(OfficialCourses.inDistrict('강남구'), isEmpty);
    });
  });

  test('사설 코스 문서를 읽는다', () {
    final course = Course.fromMap('abc', {
      'name': '우리 동네 한 바퀴',
      'district': '노원구',
      'hearts': 12,
      'authorName': '달리는곰',
      'points': [
        {'lat': 37.65, 'lng': 127.06},
        {'lat': 37.651, 'lng': 127.06},
      ],
    });
    expect(course.official, isFalse);
    expect(course.hearts, 12);
    expect(course.points.length, 2);
    expect(course.distanceMeters, closeTo(111, 2));
  });
}
