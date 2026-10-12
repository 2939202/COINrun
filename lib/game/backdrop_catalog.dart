import 'package:flutter/painting.dart';

// ============================================================
// 내 캐릭터 화면 배경
//
// 4가지입니다. 흰색·검은색은 누구나 가진 기본 배경이고,
// 안개 들판·숲길은 잡화점에서 삽니다. (그림은 살짝 픽셀화한 것, assets/backgrounds/)
// 고르는 것은 내 캐릭터 > 인벤토리에서 합니다.
// ============================================================
class Backdrop {
  final String id; // Firestore에 저장되는 값
  final String name;
  final int price; // 0이면 기본 배경
  final Color? color; // 단색 배경
  final String? asset; // 그림 배경
  final bool dark; // 어두운 배경이면 위에 얹는 글자를 밝게

  const Backdrop({
    required this.id,
    required this.name,
    required this.price,
    this.color,
    this.asset,
    required this.dark,
  });

  bool get isFree => price == 0;
}

class BackdropCatalog {
  BackdropCatalog._();

  static const Backdrop white = Backdrop(
    id: 'white',
    name: '흰색',
    price: 0,
    color: Color(0xFFFFFFFF),
    dark: false,
  );
  static const Backdrop black = Backdrop(
    id: 'black',
    name: '검은색',
    price: 0,
    color: Color(0xFF1B1714),
    dark: true,
  );
  static const Backdrop fog = Backdrop(
    id: 'fog',
    name: '안개 들판',
    price: 1500,
    asset: 'assets/backgrounds/fog.png',
    dark: false,
  );
  static const Backdrop forest = Backdrop(
    id: 'forest',
    name: '숲길',
    price: 2000,
    asset: 'assets/backgrounds/forest.png',
    dark: true,
  );

  static const List<Backdrop> all = [white, black, fog, forest];

  // 잡화점에서 파는 것
  static List<Backdrop> get forSale => [
    for (final b in all)
      if (!b.isFree) b,
  ];

  // 모르는 id면 흰색입니다. (예전 문서도 흰색으로 읽힙니다)
  static Backdrop byId(String? id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return white;
  }
}
