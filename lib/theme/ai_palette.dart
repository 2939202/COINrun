import 'package:flutter/material.dart';

// ============================================================
// AI 평가 탭의 색
//
// 갈색 한 계열을 명암 6단계로만 씁니다. 색이 여럿 섞이면 무엇이 중요한지 흐려지고,
// 같은 계열이면 차분하게 정돈돼 보입니다. 뜻은 명암으로 나눕니다.
//
//   잘한 점   - 짙은 갈색(700) 바탕에 밝은 글자  ▲   가장 진하게, 눈이 먼저 갑니다
//   아쉬운 점 - 밝은 갈색(300) 바탕에 먹색 글자  ▼   중간 밝기
//   참고      - 종이색(50) 바탕에 테두리만        ·    가장 옅게
//
// 색만으로 구분하면 색약이면 알아보기 어려워서 ▲ ▼ · 표시를 같이 붙입니다.
// ============================================================
class AiPalette {
  AiPalette._();

  static const Color ink = Color(0xFF1B1714); // 900
  static const Color deep = Color(0xFF4A3628); // 700
  static const Color mid = Color(0xFF8A6A3E); // 500
  static const Color soft = Color(0xFFC9A87C); // 300
  static const Color pale = Color(0xFFEADBC3); // 150
  static const Color paper = Color(0xFFF7F1E6); // 50

  // 좋아진 것 / 나빠진 것 (비교 줄의 변화 표시, 조언 말풍선)
  static const Color goodFill = deep;
  static const Color goodText = paper;
  static const Color badFill = soft;
  static const Color badText = ink;
}
