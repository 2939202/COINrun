import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ============================================================
// 앱 안의 작은 웹 서버 (3D 캐릭터 뷰어용)
//
// 3D 뷰어(assets/viewer/index.html)는 웹뷰 안에서 돕니다. 웹뷰는 앱 안의 파일을
// 바로 열면(file://) 보안 규칙 때문에 모듈 스크립트와 모델 파일을 못 읽습니다.
// 그래서 폰 안에서만 열리는 주소(127.0.0.1)에 작은 서버를 띄우고, 앱에 같이 넣은
// 파일(assets/)을 그대로 내줍니다. 밖에서는 접속할 수 없습니다.
//
// 한 번 띄우면 앱이 꺼질 때까지 둡니다. 화면마다 새로 띄우지 않습니다.
// ============================================================
class AssetServer {
  AssetServer._();

  static final AssetServer instance = AssetServer._();

  Future<Uri>? _base;

  // 서버 주소. 처음 부를 때 띄웁니다. 예: http://127.0.0.1:41234/
  Future<Uri> get base => _base ??= _start();

  // assets/ 아래 경로의 주소. 예: url('viewer/index.html')
  Future<Uri> url(String path, [Map<String, String>? query]) async {
    final Uri root = await base;
    return root.replace(path: '/$path', queryParameters: query);
  }

  static const Map<String, String> _types = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'glb': 'model/gltf-binary',
    'json': 'application/json',
    'png': 'image/png',
    'jpg': 'image/jpeg',
  };

  Future<Uri> _start() async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    server.listen(_handle);
    return Uri.parse('http://127.0.0.1:${server.port}/');
  }

  Future<void> _handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    final String path = Uri.decodeComponent(request.uri.path).substring(1);
    // ../ 로 assets 밖을 읽지 못하게 막습니다. (rootBundle은 원래 assets만 읽습니다)
    if (path.isEmpty || path.contains('..')) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    try {
      final ByteData data = await rootBundle.load('assets/$path');
      response.headers.contentType = ContentType.parse(
        _types[path.split('.').last] ?? 'application/octet-stream',
      );
      response.add(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (error) {
      debugPrint('AssetServer: $path 없음 ($error)');
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }
}
