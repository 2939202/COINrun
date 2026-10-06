import 'package:contact/game/run_calendar.dart';
import 'package:contact/game/run_insights.dart';
import 'package:contact/screens/ai_report_screen.dart';
import 'package:contact/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('리포트 밑 달력은 접혀 있다가 누르면 펼쳐진다', (tester) async {
    final DateTime now = DateTime(2026, 10, 7, 12);
    final report = RunInsights.analyze(
      range: InsightRange.week,
      statsByKey: const {},
      now: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: InsightScoreCard(
              report: report,
              calendar: RunCalendar.of(now, const []),
            ),
          ),
        ),
      ),
    );

    // 접힌 상태: 요일 머리줄이 없습니다.
    expect(find.text('2026.10 달력'), findsOneWidget);
    expect(find.text('수'), findsNothing);

    await tester.tap(find.text('2026.10 달력'));
    await tester.pumpAndSettle();
    expect(find.text('수'), findsOneWidget);

    await tester.tap(find.text('2026.10 달력'));
    await tester.pumpAndSettle();
    expect(find.text('수'), findsNothing);
  });
}
