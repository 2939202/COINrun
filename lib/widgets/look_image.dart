import 'package:flutter/material.dart';

// ============================================================
// 캐릭터 그림 (홈 카드, 플레이어 카드)
//
// 사람은 그림 그대로, 강아지는 3D 화면과 같은 단계 그림체를 입혀서 보여줍니다.
// (assets/viewer/index.html의 DOG_STAGES와 맞춰 둡니다)
//   1단계: 아주 큰 픽셀, 흑백   2단계: 큰 픽셀, 흑백   3단계: 고운 그림, 색은 반쯤
//
// 픽셀은 그림을 아주 작게 읽어 들인 뒤(cacheWidth) 칸 그대로 키워서 만듭니다.
// ============================================================
class LookImage extends StatelessWidget {
  final String asset;
  final int? dogStage; // 사람이면 null
  final BoxFit fit;

  const LookImage({
    super.key,
    required this.asset,
    this.dogStage,
    this.fit = BoxFit.contain,
  });

  // 단계별 (가로 픽셀 칸 수, 채도). 칸 수가 null이면 픽셀로 뭉개지 않습니다.
  static const Map<int, (int?, double)> _stages = {
    1: (12, 0),
    2: (20, 0),
    3: (null, 0.55),
  };

  static List<double> _saturation(double s) {
    const double r = 0.299, g = 0.587, b = 0.114;
    final double k = 1 - s;
    return [
      r * k + s, g * k, b * k, 0, 0, //
      r * k, g * k + s, b * k, 0, 0, //
      r * k, g * k, b * k + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    final int? stage = dogStage;
    if (stage == null) {
      return Image.asset(asset, fit: fit, filterQuality: FilterQuality.none);
    }
    final (int? blocks, double sat) = _stages[stage] ?? _stages[1]!;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_saturation(sat)),
      child: Image.asset(
        asset,
        fit: fit,
        cacheWidth: blocks,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
