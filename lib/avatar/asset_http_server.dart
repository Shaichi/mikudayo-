import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Serve `assets/web/live2d/` qua HTTP loopback (127.0.0.1) để WebView có origin
/// hợp lệ (http), tránh CORS file:// trên Android.
///
/// Động cơ: `loadFlutterAsset` trên Android load qua `file://` (origin null) →
/// Chromium chặn fetch model. Serve qua HTTP loopback cho ta origin
/// `http://127.0.0.1:<port>` hợp lệ, không cần native `WebViewAssetLoader`.
///
/// Lưu ý bảo mật: server CHỈ bind 127.0.0.1 (loopback), không lộ ra ngoài máy.
class AssetHttpServer {
  AssetHttpServer({this.assetRoot = 'assets/web/live2d/'});

  /// Thư mục asset được serve (kết thúc bằng '/'), vd `assets/web/live2d/`.
  final String assetRoot;

  HttpServer? _server;
  int? _port;

  int? get port => _port;
  String get baseUrl =>
      _port == null ? '' : 'http://127.0.0.1:$_port/index.html';

  Future<void> start() async {
    if (_server != null) return;
    // Bind loopback; tìm cổng trống tự động.
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  void _handle(HttpRequest req) {
    // Normalize path: strip query, map đến file trong [assetRoot].
    final uri = req.uri;
    var path = uri.path;
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isEmpty || path.endsWith('/')) path = 'index.html';

    // Ngăn path traversal.
    // uri.path còn percent-encode (tên file như "Hold Staff2.exp3.json" có khoảng trắng).
    final segments = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList();
    if (segments.any((s) => s == '..')) {
      req.response.statusCode = HttpStatus.forbidden;
      req.response.close();
      return;
    }

    final assetKey = '$assetRoot${segments.join('/')}';
    final loader = rootBundle;

    Future<void> serve() async {
      try {
        final data = await loader.load(assetKey);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        req.response.headers.contentType = _contentTypeFor(segments.last);
        req.response.contentLength = bytes.length;
        req.response.add(bytes);
        await req.response.close();
      } catch (e) {
        _notFound(req, 'asset $assetKey: $e');
      }
    }

    // Đẩy việc serve ra ngoài để không chặn listener (giữ server nhẹ).
    scheduleMicrotask(serve);
  }

  static ContentType _contentTypeFor(String filename) {
    final ext = filename.contains('.')
        ? filename.substring(filename.lastIndexOf('.') + 1).toLowerCase()
        : '';
    switch (ext) {
      case 'html':
        return ContentType.html;
      case 'js':
        return ContentType('application', 'javascript', charset: 'utf-8');
      case 'json':
        return ContentType.json;
      case 'moc3':
        return ContentType('application', 'octet-stream');
      case 'png':
        return ContentType('image', 'png');
      default:
        return ContentType.binary;
    }
  }

  void _notFound(HttpRequest req, String detail) {
    req.response.statusCode = HttpStatus.notFound;
    req.response.headers.contentType = ContentType.text;
    req.response.write(detail);
    req.response.close();
  }
}
