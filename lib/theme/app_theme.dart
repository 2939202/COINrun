import 'package:flutter/material.dart';

// ============================================================
// 앱 전체 디자인 기준 (나이키 런 스타일: 흑백 + 포인트 색 하나)
// 화면에서는 Color(0x...)나 fontSize를 직접 쓰지 말고 여기 값을 가져다 씁니다.
// ============================================================

// 색상표
class AppColors {
  AppColors._();

  static const Color black = Color(0xFF111111);
  static const Color white = Color(0xFFFFFFFF);
  static const Color volt = Color(0xFFD4FF3A); // 포인트 색 - 강조할 곳에만 아껴서 사용
  static const Color grey100 = Color(0xFFF5F5F5); // 카드 배경
  static const Color grey300 = Color(0xFFE5E5E5); // 구분선, 테두리
  static const Color grey500 = Color(0xFF8D8D8D); // 보조 글자
  static const Color grey700 = Color(0xFF4B4B4B);
  static const Color error = Color(0xFFD43F21);
}

// 간격 (여백은 이 값들 중에서만 고릅니다)
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

// 모서리 둥글기
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 16;
  static const double pill = 999; // 알약 모양 버튼
}

class AppTheme {
  AppTheme._();

  // 글자 스타일 - 큰 숫자는 굵고 크게, 라벨은 작고 회색으로
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 64,
      fontWeight: FontWeight.w900,
      height: 1.0,
      letterSpacing: -2,
    ), // 러닝 시간 같은 메인 숫자
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
    ), // 화면 큰 제목
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.grey500,
      letterSpacing: 0.5,
    ), // 숫자 아래 작은 설명
  );

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.black,
      onPrimary: AppColors.white,
      secondary: AppColors.volt,
      onSecondary: AppColors.black,
      surface: AppColors.white,
      onSurface: AppColors.black,
      onSurfaceVariant: AppColors.grey500,
      surfaceContainerHighest: AppColors.grey100,
      outline: AppColors.grey300,
      error: AppColors.error,
    );

    const pillShape = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.white,
      // apply()는 모든 글자를 검은색으로 덮어쓰므로, 회색 라벨(labelMedium)은 원래 색으로 되돌립니다.
      textTheme: _textTheme
          .apply(bodyColor: AppColors.black, displayColor: AppColors.black)
          .copyWith(labelMedium: _textTheme.labelMedium),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.black,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: pillShape,
          padding: buttonPadding,
          textStyle: _textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          side: const BorderSide(color: AppColors.black, width: 1.5),
          shape: pillShape,
          padding: buttonPadding,
          textStyle: _textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.black),
      ),
      cardTheme: CardThemeData(
        color: AppColors.grey100,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.grey300,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.black),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.black,
        linearTrackColor: AppColors.grey300,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.black,
        contentTextStyle: TextStyle(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
