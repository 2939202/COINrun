// 숫자를 화면에 보여줄 문자열로 바꾸는 함수 모음

// 00:00 또는 1시간이 넘으면 00:00:00
String formatDuration(Duration duration) {
  final String mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final String ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    final String hh = duration.inHours.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
  return '$mm:$ss';
}

// 누적 시간처럼 긴 시간: 시:분 (예: 2:05)
String formatHoursMinutes(int totalSeconds) {
  final int hours = totalSeconds ~/ 3600;
  final String minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(
    2,
    '0',
  );
  return '$hours:$minutes';
}

// 2026-09-21 -> 9월 21일
String formatMonthDay(DateTime date) => '${date.month}월 ${date.day}일';

// 거리는 항상 km, 소수점 둘째 자리까지 (예: 0.35)
String formatKm(double meters) => (meters / 1000).toStringAsFixed(2);

// 6.5(분) -> 6'30"
String formatPace(double? paceMinPerKm) {
  if (paceMinPerKm == null || !paceMinPerKm.isFinite || paceMinPerKm <= 0) {
    return "-'--\"";
  }
  final int totalSeconds = (paceMinPerKm * 60).round();
  final int minutes = totalSeconds ~/ 60;
  final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return "$minutes'$seconds\"";
}
