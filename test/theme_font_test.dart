import 'package:contact/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 글꼴을 한 군데라도 빠뜨리면 그 부분만 기본 글꼴로 나옵니다.
  // 눈으로는 알아채기 어려워서 테스트로 박아둡니다.
  group('글꼴이 모든 곳에 닿는지', () {
    final theme = AppTheme.light();
    final t = theme.textTheme;

    test('제목과 큰 숫자는 함렛', () {
      for (final entry in {
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
      }.entries) {
        expect(
          entry.value?.fontFamily,
          AppTheme.hangulSerifFont,
          reason: '${entry.key}가 함렛이 아닙니다',
        );
      }
    });

    test('본문과 라벨은 자연산스', () {
      for (final entry in {
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      }.entries) {
        expect(
          entry.value?.fontFamily,
          AppTheme.sansFont,
          reason: '${entry.key}가 자연산스가 아닙니다',
        );
      }
    });

    // ThemeData의 fontFamily는 textTheme에만 닿습니다. AppBar는 따로 적어야 합니다.
    test('화면 제목(AppBar)은 함렛', () {
      expect(
        theme.appBarTheme.titleTextStyle?.fontFamily,
        AppTheme.hangulSerifFont,
      );
    });

    test('영문 소제목은 자연산스', () {
      expect(AppTheme.caption.fontFamily, AppTheme.sansFont);
    });

    test('큰 숫자는 함렛', () {
      expect(AppTheme.number.fontFamily, AppTheme.hangulSerifFont);
      // copyWith로 크기나 색을 바꿔도 글꼴은 남아야 합니다.
      expect(
        AppTheme.number.copyWith(fontSize: 64).fontFamily,
        AppTheme.hangulSerifFont,
      );
    });
  });
}
