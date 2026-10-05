import 'dart:io';

import 'package:contact/theme/app_theme.dart';
import 'package:flutter/material.dart';
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

    // ThemeData의 fontFamily는 textTheme에만 닿습니다. 스타일을 통째로 바꿔 끼우는
    // 자리(AppBar 제목, 버튼, 스낵바)는 따로 적어야 합니다.
    test('화면 제목(AppBar)은 함렛', () {
      expect(
        theme.appBarTheme.titleTextStyle?.fontFamily,
        AppTheme.hangulSerifFont,
      );
    });

    test('버튼 글자도 자연산스', () {
      final elevated = theme.elevatedButtonTheme.style?.textStyle?.resolve({});
      final outlined = theme.outlinedButtonTheme.style?.textStyle?.resolve({});
      expect(elevated?.fontFamily, AppTheme.sansFont);
      expect(outlined?.fontFamily, AppTheme.sansFont);
    });

    test('스낵바 글자도 자연산스', () {
      expect(
        theme.snackBarTheme.contentTextStyle?.fontFamily,
        AppTheme.sansFont,
      );
    });

    test('영문 소제목은 자연산스', () {
      expect(AppTheme.caption.fontFamily, AppTheme.sansFont);
    });

    test('숫자는 함렛', () {
      expect(AppTheme.number.fontFamily, AppTheme.hangulSerifFont);
      // copyWith로 크기나 색을 바꿔도 글꼴은 남아야 합니다.
      expect(
        AppTheme.number.copyWith(fontSize: 64).fontFamily,
        AppTheme.hangulSerifFont,
      );
    });

    // 파일에 없는 굵기를 주면 획이 억지로 두꺼워져 뭉개집니다.
    test('글꼴 파일에 있는 굵기만 쓴다', () {
      final sansWeights = [FontWeight.w400, FontWeight.w500];
      for (final style in [
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ]) {
        expect(sansWeights, contains(style?.fontWeight));
      }
      for (final style in [
        t.displayLarge,
        t.headlineMedium,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
      ]) {
        expect(style?.fontWeight, FontWeight.w600);
      }
    });
  });

  // 예전 글꼴(조선굵은명조, DM Serif)을 다시 쓰는 곳이 생기지 않게 막습니다.
  test('코드에 예전 글꼴 이름이 남아 있지 않다', () {
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final String text = file.readAsStringSync();
      if (text.contains("'ChosunKm'") || text.contains("'DMSerif'")) {
        found.add(file.path);
      }
    }
    expect(found, isEmpty);
  });
}
