import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contact/game/run_calendar.dart';
import 'package:contact/models/run_log.dart';
import 'package:flutter_test/flutter_test.dart';

RunLog _run(DateTime at, double km) => RunLog.fromMap(
  'r${at.millisecondsSinceEpoch}',
  {'distanceMeters': km * 1000, 'createdAt': Timestamp.fromDate(at)},
);

void main() {
  // 2026-10-07 수요일. 10월 1일은 목요일, 31일은 토요일입니다.
  final DateTime now = DateTime(2026, 10, 7, 12);

  test('이번 달을 월요일부터 7칸씩 펼친다', () {
    final cal = RunCalendar.of(now, const []);
    expect(cal.first, DateTime(2026, 9, 28)); // 10/1이 든 주의 월요일
    expect(cal.weeks, 5);
    expect(cal.rows.length, 5);
    expect(cal.rows.every((row) => row.length == 7), isTrue);
    expect(cal.rows.last.last, DateTime(2026, 11, 1)); // 마지막 칸은 일요일
  });

  test('불러올 기간은 첫 칸부터 마지막 칸 다음 날까지', () {
    final (start, end) = RunCalendar.rangeOf(now);
    expect(start, DateTime(2026, 9, 28));
    expect(end, DateTime(2026, 11, 2));
  });

  test('6줄이 필요한 달도 있다', () {
    // 2026-08: 1일이 토요일, 31일이 월요일
    expect(RunCalendar.of(DateTime(2026, 8, 15), const []).weeks, 6);
  });

  test('같은 날 여러 번 뛰면 거리를 더한다', () {
    final cal = RunCalendar.of(now, [
      _run(DateTime(2026, 10, 5, 7), 3),
      _run(DateTime(2026, 10, 5, 19), 2.5),
      _run(DateTime(2026, 10, 6, 7), 4),
    ]);
    expect(cal.kmOn(DateTime(2026, 10, 5)), closeTo(5.5, 1e-9));
    expect(cal.kmOn(DateTime(2026, 10, 6)), 4);
    expect(cal.kmOn(DateTime(2026, 10, 7)), 0);
  });

  test('이번 주와 이번 달을 구분한다', () {
    final cal = RunCalendar.of(now, const []);
    expect(cal.isThisWeek(DateTime(2026, 10, 5)), isTrue); // 월
    expect(cal.isThisWeek(DateTime(2026, 10, 11)), isTrue); // 일
    expect(cal.isThisWeek(DateTime(2026, 10, 12)), isFalse);
    expect(cal.isThisMonth(DateTime(2026, 9, 30)), isFalse);
    expect(cal.isThisMonth(DateTime(2026, 10, 31)), isTrue);
    expect(cal.isFuture(DateTime(2026, 10, 8)), isTrue);
    expect(cal.isFuture(DateTime(2026, 10, 7)), isFalse);
  });

  test('게이지는 가장 많이 뛴 날이 가득, 최소 5km', () {
    expect(
      RunCalendar.of(now, [_run(DateTime(2026, 10, 2, 7), 2)]).gaugeFullKm,
      5,
    );
    expect(
      RunCalendar.of(now, [_run(DateTime(2026, 10, 2, 7), 8)]).gaugeFullKm,
      8,
    );
  });
}
