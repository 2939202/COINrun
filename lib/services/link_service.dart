import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ============================================================
// 친구 링크 받기
//
// 플레이어 카드 QR을 휴대폰 카메라로 찍거나, 공유받은 링크(coinrun://app/player/<uid>)를
// 누르면 안드로이드가 이 앱을 엽니다. MainActivity.kt가 그 링크를 이 채널로 넘겨줍니다.
//   initialLink()  앱이 꺼져 있다가 링크로 켜졌을 때 그 링크 (한 번만)
//   links          앱이 켜져 있을 때 들어온 링크
// 앱 안에 카메라 스캐너는 넣지 않습니다. 휴대폰 기본 카메라로 찍으면 됩니다.
// ============================================================
class LinkService {
  LinkService._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        _links.add(call.arguments as String);
      }
    });
  }

  static final LinkService instance = LinkService._();

  static const MethodChannel _channel = MethodChannel('coinrun/links');
  final StreamController<String> _links = StreamController.broadcast();

  Stream<String> get links => _links.stream;

  Future<String?> initialLink() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<String>('getInitialLink');
    } catch (_) {
      return null;
    }
  }
}
