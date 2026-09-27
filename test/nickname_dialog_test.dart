import 'package:contact/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 다이얼로그를 띄우고, 돌려받은 값을 담아두는 시험용 화면
Widget _host(String current, void Function(String?) onClosed) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final String? name = await showDialog<String>(
              context: context,
              builder: (context) => NicknameDialog(current: current),
            );
            onClosed(name);
          },
          child: const Text('열기'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  group('닉네임 바꾸기 다이얼로그', () {
    // 예전에는 다이얼로그 바깥에서 컨트롤러를 만들고 showDialog가 끝나자마자 버렸습니다.
    // 닫히는 애니메이션이 도는 동안 TextField가 다시 그려지면서
    // "used after being disposed" 오류로 빨간 화면이 떴습니다.
    // pumpAndSettle이 그 애니메이션을 끝까지 돌리므로 이 테스트가 그때를 잡아냅니다.
    testWidgets('저장하고 닫혀도 오류가 나지 않는다', (tester) async {
      String? result;
      await tester.pumpWidget(_host('러너3f9a', (name) => result = name));
      await _open(tester);

      await tester.enterText(find.byType(TextField), '달리는사람');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(result, '달리는사람');
    });

    testWidgets('취소하고 닫혀도 오류가 나지 않는다', (tester) async {
      String? result = '아직';
      await tester.pumpWidget(_host('러너3f9a', (name) => result = name));
      await _open(tester);

      await tester.enterText(find.byType(TextField), '안쓸이름');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(result, isNull);
    });

    testWidgets('지금 닉네임이 미리 들어가 있다', (tester) async {
      await tester.pumpWidget(_host('러너3f9a', (_) {}));
      await _open(tester);

      expect(find.text('러너3f9a'), findsOneWidget);
    });

    testWidgets('앞뒤 공백은 지우고 돌려준다', (tester) async {
      String? result;
      await tester.pumpWidget(_host('러너3f9a', (name) => result = name));
      await _open(tester);

      await tester.enterText(find.byType(TextField), '  달리는사람  ');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(result, '달리는사람');
    });

    // 빈 이름으로 저장되면 홈 화면에서 이름이 사라집니다.
    testWidgets('빈 칸이면 저장 버튼이 잠긴다', (tester) async {
      String? result = '아직';
      await tester.pumpWidget(_host('러너3f9a', (name) => result = name));
      await _open(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      final save = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '저장'),
      );
      expect(save.onPressed, isNull);

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      // 눌러도 닫히지 않습니다.
      expect(find.byType(TextField), findsOneWidget);
      expect(result, '아직');
    });
  });
}
