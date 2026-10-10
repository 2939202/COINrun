import 'package:contact/game/run_load.dart';
import 'package:contact/game/run_rules.dart';
import 'package:contact/models/run_record.dart';
import 'package:contact/screens/run_report.dart';
import 'package:contact/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const RunRecord _record = RunRecord(
  elapsed: Duration(minutes: 30),
  movingTime: Duration(minutes: 30),
  distanceMeters: 5000,
  steps: 4900,
  stepsEstimated: false,
);
const RunReward _reward = RunReward(
  gold: 490,
  exp: 300,
  levelBefore: 1,
  levelAfter: 1,
);

Future<int?> _open(WidgetTester tester, Future<void> Function() act) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final load = RunLoad.of(_record, const [], now: DateTime(2026, 10, 9));
  int? result;
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (c) {
          ctx = c;
          return const Scaffold();
        },
      ),
    ),
  );
  showRunReport(ctx, _record, _reward, load).then((v) => result = v);
  await tester.pump(const Duration(seconds: 1));
  await act();
  await tester.tap(find.text('확인'));
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return result;
}

void main() {
  testWidgets('아무것도 안 누르면 계산값 그대로 저장', (tester) async {
    final computed = RunLoad.of(_record, const [], now: DateTime(2026, 10, 9));
    final int? chosen = await _open(tester, () async {});
    expect(chosen, computed.level);
  });

  testWidgets('다른 칸을 누르면 그 단계가 저장되고 설명이 열린다', (tester) async {
    final computed = RunLoad.of(_record, const [], now: DateTime(2026, 10, 9));
    final int other = computed.level == 5 ? 4 : 5;
    final int? chosen = await _open(tester, () async {
      await tester.tap(find.text('$other'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.textContaining('계산값 ${computed.level}'), findsWidgets);
    });
    expect(chosen, other);
  });
}
