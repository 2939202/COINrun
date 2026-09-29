import 'package:contact/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 글꼴을 한 군데라도 빠뜨리면 그 부분만 기본 글꼴로 나옵니다.
  // 눈으로는 알아채기 어려워서 테스트로 박아둡니다.
  group('글꼴이 모든 곳에 닿는지', () {
    final theme = AppTheme.light();

    test('본문 글자는 전부 한글 글꼴', () {
      final t = theme.textTheme;
      for (final entry in {
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'headlineMedium': t.headlineMedium,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'displayLarge': t.displayLarge,
      }.entries) {
        expect(
          entry.value?.fontFamily,
          AppTheme.koreanFont,
          reason: '${entry.key}에 글꼴이 빠졌습니다',
        );
      }
    });

    // ThemeData의 fontFamily는 textTheme에만 닿습니다. AppBar는 따로 적어야 합니다.
    test('화면 제목(AppBar)에도 글꼴이 붙는다', () {
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, AppTheme.koreanFont);
    });

    test('영문 소제목에도 글꼴이 붙는다', () {
      expect(AppTheme.caption.fontFamily, AppTheme.koreanFont);
    });

    test('큰 숫자는 세리프 글꼴', () {
      expect(AppTheme.number.fontFamily, AppTheme.numberFont);
      // copyWith로 크기나 색을 바꿔도 글꼴은 남아야 합니다.
      expect(
        AppTheme.number.copyWith(fontSize: 64).fontFamily,
        AppTheme.numberFont,
      );
    });
  });
}
