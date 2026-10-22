import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/models/conversation_turn.dart';
import 'asset_http_server.dart';
import 'avatar_controller.dart';
import 'avatar_look.dart';

/// Avatar Miku Live2D — render qua WebView + PixiJS + pixi-live2d-display.
///
/// Kiến trúc:
/// - `assets/web/live2d/index.html` render model. Serve qua [AssetHttpServer]
///   (HTTP loopback) → origin `http://127.0.0.1:<port>` hợp lệ → fetch model
///   cùng origin, không CORS.
/// - JS → Flutter: `window.chrome.webview.postMessage` (Android) hoặc JS channel
///   `MikuBridge` → [WebViewController.addJavaScriptChannel].
/// - Flutter → JS: `runJavaScript("window.onFlutterMessage(...)")`.
/// - Lip-sync: Flutter gửi toàn bộ cues 1 lần (`{type:'speech', cues, duration}`),
///   JS tự nội suy độ mở miệng trong requestAnimationFrame.
class Live2dAvatar extends ConsumerStatefulWidget {
  const Live2dAvatar({super.key, this.width = 320, this.height = 380});

  final double width;
  final double height;

  @override
  ConsumerState<Live2dAvatar> createState() => _Live2dAvatarState();
}

class _Live2dAvatarState extends ConsumerState<Live2dAvatar> {
  final Completer<void> _controllerCompleter = Completer<void>();
  final AssetHttpServer _httpServer = AssetHttpServer();
  late final WebViewController _controller;
  bool _disposed = false;
  bool _webViewReady = false;
  bool _modelLoaded = false;
  String? _loadError;
  int _speechSeq = 0;

  // Giá trị đã gửi lên web — tránh gửi lại khi state không đổi.
  MikuEmotion? _lastEmotion;
  int _lastSpeechSeq = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(avatarControllerProvider, (prev, next) {
      if (next.emotion != _lastEmotion) {
        _lastEmotion = next.emotion;
        _setExpression(next.emotion);
      }
      // Cues mới → gửi toàn bộ lên JS 1 lần (JS tự chạy theo thời gian).
      if (next.speechSeq != _lastSpeechSeq) {
        _lastSpeechSeq = next.speechSeq;
        if (next.mouthCues.isNotEmpty) _setMouthCues(next.mouthCues);
      }
    });
    ref.listenManual(avatarLookProvider, (prev, next) {
      if (_modelLoaded) _setLook(next);
    });
    _initWebview();
  }

  Future<void> _setLook(AvatarLook look) =>
      _post({'type': 'exps', 'names': look.exps});

  Future<void> _initWebview() async {
    try {
      // Serve assets qua HTTP loopback trước, rồi load bằng loadRequest.
      await _httpServer.start();
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'MikuBridge',
          onMessageReceived: (message) {
            // JS postMessage → message.message là JSON string {type:...}.
            _handleWebMessage(message.message);
          },
        )
        ..loadRequest(Uri.parse(_httpServer.baseUrl));
      _webViewReady = true;
      _controllerCompleter.complete();
    } catch (e) {
      debugPrint('Live2dAvatar init failed: $e');
      _loadError = 'Không khởi tạo được trình hiển thị avatar.';
      _controllerCompleter.complete();
    }
    if (!mounted) return;
    setState(() {});
  }

  void _handleWebMessage(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        if (data['type'] == 'loaded') {
          // Model sẵn sàng → reset để gửi lại trạng thái hiện tại (các lệnh
          // trước đây bị bỏ vì web chưa load xong).
          _lastEmotion = null;
          final cur = ref.read(avatarControllerProvider);
          _lastEmotion = cur.emotion;
          _modelLoaded = true;
          _loadError = null;
          _setExpression(cur.emotion);
          _setLook(ref.read(avatarLookProvider));
          debugPrint('Live2dAvatar: model loaded, emotion=${cur.emotion}');
          if (mounted) setState(() {});
        } else if (data['type'] == 'error') {
          debugPrint('WEB error: ${data['message']}');
          _loadError = 'Không tải được mô hình Miku.';
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Live2dAvatar bad web message: $e');
    }
  }

  Future<void> _retryLoad() async {
    if (!_webViewReady) return;
    setState(() {
      _modelLoaded = false;
      _loadError = null;
    });
    await _controller.reload();
  }

  /// Gửi JSON lên JS qua window.onFlutterMessage. Bỏ qua khi web chưa load xong.
  Future<void> _post(Map<String, dynamic> data) async {
    if (_disposed) return;
    try {
      final escaped = jsonEncode(
        data,
      ).replaceAll('\\', '\\\\').replaceAll("'", "\\'");
      await _controller.runJavaScript("window.onFlutterMessage('$escaped')");
    } catch (e) {
      debugPrint('runJavaScript error: $e');
    }
  }

  Future<void> _setExpression(MikuEmotion emotion) =>
      _post({'type': 'emotion', 'value': emotion.name});

  /// Gửi toàn bộ mouth cues 1 lần; JS tự chạy theo thời gian. Đảm bảo không
  /// nói đè khi có turn mới (seq tăng).
  Future<void> _setMouthCues(List<MouthCue> cues) async {
    _speechSeq++;
    final seq = _speechSeq;
    final ms = cues.map((c) => {'t_ms': c.tMs, 'mouth': c.mouth}).toList();
    final durationMs = cues.isNotEmpty ? cues.last.tMs : 0;
    await _post({
      'type': 'speech',
      'seq': seq,
      'cues': ms,
      'duration_ms': durationMs,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _httpServer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controllerCompleter.isCompleted && _webViewReady)
            WebViewWidget(controller: _controller),
          if (!_modelLoaded)
            ColoredBox(
              color: const Color(0xFFF4FBFA).withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x6639C5BB)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loadError == null)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF0F7F7A),
                          ),
                        )
                      else
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Color(0xFFE0508F),
                          size: 30,
                        ),
                      const SizedBox(height: 12),
                      Text(
                        _loadError ?? 'Đang tải mô hình Miku…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF17323A)),
                      ),
                      if (_loadError != null && _webViewReady) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _retryLoad,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
