import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/asset_server.dart';
import '../theme/app_theme.dart';

// 대결에서 한 차례. 같은 차례가 두 번 와도 다시 움직이도록 번호(turn)로 구분합니다.
class CharacterStrike {
  final int turn;
  final bool byMe; // 내가 쳤는지
  final bool landed; // 맞았는지 (false면 상대가 피합니다)

  const CharacterStrike({
    required this.turn,
    required this.byMe,
    required this.landed,
  });
}

// ============================================================
// 3D 캐릭터
//
// 웹뷰 안에서 three.js로 assets/models/character.glb를 띄웁니다.
// (assets/viewer/index.html, 파일은 services/asset_server.dart가 내줍니다)
//
//   me만 주면     내 캐릭터 화면. 한 명이 가만히 서 있고, 가로로 끌면 돕니다.
//   foe도 주면    게임 플레잉 대결. 두 명이 마주 보고, strike가 오면 치고 맞습니다.
//   pair: true    캐릭터 고르기. 두 명이 나란히 앞을 봅니다.
//
// 홈 카드의 얼굴은 3D가 아니라, 같은 뷰어(?face=1)로 미리 찍어 둔 그림입니다.
// (assets/icons/face_*.png) 홈은 자주 열려서 웹뷰를 띄우지 않습니다.
//
// 그림체는 픽셀 느낌에 잔잔한 노이즈를 얹은 것입니다. (뷰어의 "필터")
//
// 켤 파츠는 game/character_outfit.dart가 정합니다. 옷이 바뀌면 바로 갈아입힙니다.
// 3D를 못 띄우면 "보이지 않아요"만 띄웁니다.
// ============================================================
class CharacterView extends StatefulWidget {
  final List<String> me;
  final List<String>? foe;
  final CharacterStrike? strike;
  final bool pair;

  const CharacterView({
    super.key,
    required this.me,
    this.foe,
    this.strike,
    this.pair = false,
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> {
  // 이 시간 안에 뜨지 않으면 못 띄우는 것으로 봅니다. (모델이 13MB라 느린 폰을 생각해 넉넉히)
  static const Duration _timeout = Duration(seconds: 40);

  WebViewController? _controller;
  bool _ready = false;
  bool _failed = false;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    // 웹(크롬)에는 웹뷰가 없습니다.
    if (kIsWeb) {
      _failed = true;
      return;
    }
    _watchdog = Timer(_timeout, () => _fail('시간 초과'));
    try {
      final Uri page = await AssetServer.instance.url('viewer/index.html', {
        'me': widget.me.join(','),
        if (widget.foe != null) 'foe': widget.foe!.join(','),
        if (widget.pair) 'pair': '1',
      });
      final WebViewController controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setOnConsoleMessage((message) => debugPrint('3D: ${message.message}'))
        ..addJavaScriptChannel('Flutter', onMessageReceived: _onMessage);
      await controller.loadRequest(page);
      if (mounted) setState(() => _controller = controller);
    } catch (error) {
      _fail('$error');
    }
  }

  void _fail(String reason) {
    debugPrint('3D 캐릭터를 띄우지 못했습니다: $reason');
    _watchdog?.cancel();
    if (mounted && !_ready) setState(() => _failed = true);
  }

  void _onMessage(JavaScriptMessage message) {
    if (!mounted) return;
    if (message.message == 'ready') {
      _watchdog?.cancel();
      setState(() => _ready = true);
      // 페이지를 여는 사이에 옷이 바뀌었을 수 있어서 한 번 맞춰 둡니다.
      _sendFighters();
    } else if (message.message.startsWith('error:')) {
      _fail(message.message);
    }
  }

  @override
  void didUpdateWidget(CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (!listEquals(oldWidget.me, widget.me) ||
        !listEquals(oldWidget.foe, widget.foe)) {
      _sendFighters();
    }
    final CharacterStrike? strike = widget.strike;
    if (strike != null && strike.turn != oldWidget.strike?.turn) {
      _controller?.runJavaScript('strike(${strike.byMe}, ${strike.landed})');
    }
  }

  void _sendFighters() => _controller?.runJavaScript(
    'setFighters(${jsonEncode(widget.me)}, ${jsonEncode(widget.foe)})',
  );

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Text(
          '보이지 않아요',
          style: AppTheme.sans.copyWith(fontSize: 13, color: AppColors.label),
        ),
      );
    }
    final WebViewController? controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null)
          // 다 뜰 때까지는 투명하게 둡니다. (빈 웹뷰가 하얗게 번쩍이지 않게)
          Opacity(
            opacity: _ready ? 1 : 0,
            child: WebViewWidget(
              controller: controller,
              // 가로로 끌면 캐릭터가 돌고, 세로로 끌면 화면이 스크롤됩니다.
              gestureRecognizers: {
                Factory<HorizontalDragGestureRecognizer>(
                  HorizontalDragGestureRecognizer.new,
                ),
              },
            ),
          ),
        if (!_ready)
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
