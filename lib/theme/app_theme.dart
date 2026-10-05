import 'package:flutter/material.dart';

// ============================================================
// 앱 전체 디자인 기준
//
// 잉크 블랙 + 크림 + 갈색. 종이에 먹으로 찍어낸 느낌을 노립니다.
// 러닝 앱이 죄다 어두운 배경에 형광색이라, 밝은 종이색으로 가면 확실히 달라 보입니다.
//
// 화면에서는 Color(0x...)나 fontSize를 직접 쓰지 말고 여기 값을 가져다 씁니다.
// ============================================================

// 색상표
class AppColors {
  AppColors._();

  // 글자와 검은 카드. 순검정(#000)이 아니라 살짝 따뜻한 먹색입니다.
  static const Color black = Color(0xFF1B1714);
  static const Color inkSoft = Color(0xFF3A332D); // 검은 카드 위의 보조 요소

  static const Color white = Color(0xFFFFFFFF);

  // 포인트 색. 아껴서 씁니다. (레벨업, 지도 경로, 내 순위 강조)
  static const Color accent = Color(0xFF8A6A3E);

  // 홈 화면 인사말과 골드 테두리. accent보다 한 톤 진합니다.
  static const Color accentDeep = Color(0xFF79583A);

  // 검은 카드 위에 올리는 포인트색. 어두운 갈색은 검정 위에서 읽히지 않아 밝게 씁니다.
  static const Color accentOnDark = Color(0xFFC9A87C);

  // 검은 카드 위의 빈 칸(진행바 바닥). 너무 어두우면 막대가 아예 안 보입니다.
  static const Color trackOnDark = Color(0xFF4B4139);

  // 검은 카드 위의 글자. 흰색보다 한 톤 낮춰서 숫자(흰색)만 튀게 합니다.
  static const Color sandOnDark = Color(0xFFCFC1A3); // LEVEL, NEXT, 경험치 설명
  static const Color paperOnDark = Color(0xFFECDDBE); // 등급표 안 글자

  static const Color cream = Color(0xFFF5EDE0); // 카드 배경
  static const Color creamDeep = Color(0xFFF1E8D7); // 캐릭터/잡화점 같은 화면 배경
  static const Color sand = Color(0xFFDBD6C0); // 구분선, 진행바 바닥
  static const Color mute = Color(0xFF8B8175); // 보조 글자
  static const Color label = Color(0xFF91857C); // 큰 숫자 아래 이름 (총 킬로미터 ...)
  static const Color gold = Color(0xFFC08A2E); // 골드 숫자

  static const Color error = Color(0xFFB4442A);
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

  // 화면 맨 아래 버튼(시작, 일시정지...)과 화면 끝 사이 최소 간격.
  // 내비게이션 바에 버튼이 바싹 붙는 기종이 있어서 16보다 조금 더 띄웁니다.
  static const double bottomButtonGap = AppSpacing.lg + 4;

  // 글꼴은 두 가지만 씁니다. 홈 화면에서 정한 것을 앱 전체 기준으로 삼습니다.
  //
  //   함렛(세리프)  - 제목, 닉네임, 큰 숫자. 기록증 같은 인상을 줍니다.
  //                  SemiBold(600) 한 벌만 넣었습니다. 굵기를 더 달라고 해도 600으로 나옵니다.
  //   자연산스(고딕) - 본문, 라벨, 영문 소제목. 굵기는 400, 500 두 가지입니다.
  //
  // 예전에는 숫자에 DM Serif, 한글에 조선일보명조를 썼습니다. DM Serif에는 한글이
  // 없어서 "3위"의 "위"만 다른 글꼴로 나오는 문제가 있었습니다.
  static const String hangulSerifFont = 'Hahmlet';
  static const String sansFont = 'JayeonSans';

  // 숫자 글꼴 (= 함렛)
  static const String numberFont = hangulSerifFont;

  static const TextStyle number = TextStyle(
    fontFamily: numberFont,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  static const TextStyle sans = TextStyle(fontFamily: sansFont);

  // 홈 화면의 숫자(골드, 레벨, 누적 기록). 한글 세리프라 "3위"처럼 숫자와 한글이
  // 한 글꼴로 이어집니다.
  static const TextStyle serifNumber = TextStyle(
    fontFamily: hangulSerifFont,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  // 영문 소제목 (GOOD TO SEE YOU, LEVEL, MY RUNNER ...)
  static const TextStyle caption = TextStyle(
    fontFamily: sansFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.4,
    color: AppColors.accent,
  );

  // 글자 스타일 - 제목과 큰 숫자는 함렛, 본문과 라벨은 자연산스
  //
  // 스타일마다 글꼴을 적습니다. ThemeData(fontFamily: ...)를 쓰면 모든 스타일의
  // 글꼴을 하나로 덮어써서 제목만 함렛으로 둘 수가 없습니다.
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: hangulSerifFont,
      fontSize: 64,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: -2,
    ), // 러닝 시간 같은 메인 숫자
    // 직접 쓰지는 않지만 비워두면 기본 글꼴(Roboto)로 나오므로 채워둡니다.
    displayMedium: TextStyle(fontFamily: hangulSerifFont),
    displaySmall: TextStyle(fontFamily: hangulSerifFont),
    headlineLarge: TextStyle(fontFamily: hangulSerifFont),
    headlineSmall: TextStyle(
      fontFamily: hangulSerifFont,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      fontFamily: hangulSerifFont,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ), // 화면 큰 제목
    titleLarge: TextStyle(
      fontFamily: hangulSerifFont,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontFamily: hangulSerifFont,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontFamily: sansFont,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontFamily: sansFont,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontFamily: sansFont,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontFamily: sansFont,
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontFamily: sansFont,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      fontFamily: sansFont,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.mute,
      letterSpacing: 0.5,
    ), // 숫자 아래 작은 설명
    labelSmall: TextStyle(
      fontFamily: sansFont,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  );

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.black,
      onPrimary: AppColors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.black,
      onSurfaceVariant: AppColors.mute,
      surfaceContainerHighest: AppColors.cream,
      outline: AppColors.sand,
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
          // 여기에 글꼴을 적지 않으면 화면 제목만 기본 글꼴로 나옵니다.
          // ThemeData의 fontFamily는 textTheme에만 닿고 AppBarTheme에는 닿지 않습니다.
          fontFamily: hangulSerifFont,
          fontSize: 20,
          fontWeight: FontWeight.w600,
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
        color: AppColors.cream,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.sand,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.black),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.black,
        linearTrackColor: AppColors.sand,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.black,
        contentTextStyle: TextStyle(
          fontFamily: sansFont,
          color: AppColors.white,
        ),
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
