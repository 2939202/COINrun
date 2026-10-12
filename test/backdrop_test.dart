import 'dart:io';

import 'package:contact/game/backdrop_catalog.dart';
import 'package:contact/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user(Map<String, dynamic> extra) => UserModel.fromMap({
  ...UserModel.initial('a', isGuest: false).toMap(),
  ...extra,
});

void main() {
  test('배경은 4개이고, 흰색·검은색은 기본입니다', () {
    expect(BackdropCatalog.all, hasLength(4));
    expect(BackdropCatalog.white.isFree, isTrue);
    expect(BackdropCatalog.black.isFree, isTrue);
    expect(BackdropCatalog.forSale.map((b) => b.id), ['fog', 'forest']);
  });

  test('예전 문서는 흰색 배경으로 읽힙니다', () {
    final user = _user({});
    expect(user.backdrop.id, 'white');
    expect(user.ownsBackdrop(BackdropCatalog.black), isTrue);
    expect(user.ownsBackdrop(BackdropCatalog.fog), isFalse);
  });

  test('산 배경은 고를 수 있고, 안 산 배경이 적혀 있으면 흰색입니다', () {
    expect(
      _user({
        'ownedBackdrops': ['fog'],
        'backdrop': 'fog',
      }).backdrop.id,
      'fog',
    );
    expect(_user({'backdrop': 'forest'}).backdrop.id, 'white');
    expect(_user({'backdrop': 'black'}).backdrop.id, 'black');
  });

  test('배경 그림 파일이 있습니다', () {
    for (final b in BackdropCatalog.all) {
      final String? asset = b.asset;
      if (asset != null) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    }
  });
}
