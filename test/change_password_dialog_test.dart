import 'package:contact/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (context) => const ChangePasswordDialog(),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester,
    String now,
    String next,
    String again,
  ) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), now);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), again);
    await tester.tap(find.text('바꾸기'));
    await tester.pump();
  }

  group('비밀번호 바꾸기 창 (서버에 보내기 전 검사)', () {
    testWidgets('새 비밀번호가 6자보다 짧으면 막는다', (tester) async {
      await open(tester);
      await fill(tester, 'oldpass', '123', '123');
      expect(find.text('새 비밀번호는 6자 이상으로 정해 주세요.'), findsOneWidget);
    });

    testWidgets('확인 칸이 다르면 막는다', (tester) async {
      await open(tester);
      await fill(tester, 'oldpass', 'newpass1', 'newpass2');
      expect(find.text('새 비밀번호가 서로 다릅니다.'), findsOneWidget);
    });

    testWidgets('지금 비밀번호와 같으면 막는다', (tester) async {
      await open(tester);
      await fill(tester, 'samepass', 'samepass', 'samepass');
      expect(find.text('지금 비밀번호와 다른 비밀번호로 정해 주세요.'), findsOneWidget);
    });

    testWidgets('취소하면 닫힌다', (tester) async {
      await open(tester);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordDialog), findsNothing);
    });
  });
}
