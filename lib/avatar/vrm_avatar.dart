import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';

import '../data/models/conversation_turn.dart';
import 'avatar_controller.dart';

/// Avatar Miku 3D thật — render VRM qua WebView + three.js.
///
/// Kiến trúc:
/// - `web/vrm/index.html` render model bằng `@pixiv/three-vrm` (CDN),
///   fetch model từ `web/vrm-model/`.
/// - Thư mục `web/` được map thành host `app.local` qua
///   `addVirtualHostNameMapping` (đồng origin → không CORS).
/// - Widget watch `avatarControllerProvider` và gửi emotion/mouth lên JS bằng
///   `postWebMessage`; JS báo `{type:'loaded'}` qua `webMessage` stream.
///
/// Widget này đọc state trực tiếp (không implement `Live2dBridge` — interface
/// đó dành cho Live2D-native tương lai). `AvatarController` giữ
/// `NoopLive2dBridge` làm fallback khi web3D không chạy.
///
/// ⚠️ Dev: `Directory.current` = thư mục project nên map `web/` đúng. Khi build
/// release Windows cần copy thư mục `web/vrm*` vào cạnh .exe (xem HANDOFF).
class VrmAvatar extends ConsumerStatefulWidget {
  const VrmAvatar({super.key});

  @override
  ConsumerState<VrmAvatar> createState() => _VrmAvatarState();
}

class _VrmAvatarState extends ConsumerState<VrmAvatar> {
  final WebviewController _controller = WebviewController();
  StreamSubscription<dynamic>? _msgSub;
  bool _disposed = false;

  /// Map cảm xúc Miku → preset VRM (khớp `EMOTION_MAP` trong index.html).
  static const Map<MikuEmotion, String> _emotionMap = {
    MikuEmotion.neutral: 'neutral',
    MikuEmotion.happy: 'happy',
    MikuEmotion.excited: 'happy',
    MikuEmotion.thinking: 'relaxed',
    MikuEmotion.embarrassed: 'happy',
    MikuEmotion.sad: 'sad',
  };

  // Giá trị đã gửi lên web — để tránh gửi lại khi state không đổi.
  MikuEmotion? _lastEmotion;
  double _lastMouth = -1;

  @override
  void initState() {
    super.initState();
    // Đẩy emotion/mouth lên web mỗi khi AvatarState đổi. Dùng listenManual thay
    // vì chạy ngoài build() (build giữ trong sạch, không side-effect).
    ref.listenManual(avatarControllerProvider, (prev, next) {
      if (next.emotion != _lastEmotion) {
        _lastEmotion = next.emotion;
        _setExpression(next.emotion);
      }
      if ((next.mouthOpen - _lastMouth).abs() > 0.005) {
        _lastMouth = next.mouthOpen;
        _setMouth(next.mouthOpen);
      }
    });
    _initWebview();
  }

  Future<void> _initWebview() async {
    // Map thư mục web (chứa vrm/index.html + vrm-model/) thành host app.local.
    // Đồng origin → fetch model không vướng CORS/file://.
    // ⚠️ addVirtualHostNameMapping dùng _methodChannel — chỉ có sau initialize().
    final mapping = 'app.local:${Directory.current.path}/web';
    debugPrint('VrmAvatar: $mapping');

    try {
      await _controller.initialize();
      // Map host sau khi init (methodChannel đã sẵn sàng).
      _controller.addVirtualHostNameMapping(
        'app.local',
        '${Directory.current.path}/web',
        WebviewHostResourceAccessKind.allow,
      );
      // Lắng nghe message từ JS — stream chỉ hoạt động sau initialize().
      _msgSub = _controller.webMessage.listen((msg) {
        if (msg is Map && msg['type'] == 'loaded') {
          // Model sẵn sàng → reset để gửi lại trạng thái hiện tại.
          _lastEmotion = null;
          _lastMouth = -1;
          if (mounted) setState(() {});
          debugPrint('VrmAvatar: model loaded');
        } else if (msg is Map && msg['type'] == 'log') {
          debugPrint('WEB: ${msg['message']}');
        }
      });
      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.loadUrl('http://app.local/vrm/index.html');
    } catch (e) {
      debugPrint('VrmAvatar init failed: $e');
    }

    if (!mounted) return;
    setState(() {}); // hiện widget Webview sau khi init
  }

  /// Gửi JSON lên JS. Bỏ qua khi web chưa sẵn sàng (sẽ re-send sau 'loaded').
  Future<void> _post(Map<String, dynamic> data) async {
    if (_disposed || !_controller.value.isInitialized) return;
    try {
      await _controller.postWebMessage(jsonEncode(data));
    } catch (e) {
      debugPrint('postWebMessage error: $e');
    }
  }

  Future<void> _setExpression(MikuEmotion emotion) =>
      _post({'type': 'emotion', 'value': _emotionMap[emotion] ?? 'neutral'});

  Future<void> _setMouth(double value) =>
      _post({'type': 'mouth', 'value': value.clamp(0.0, 1.0)});

  @override
  void dispose() {
    _disposed = true;
    _msgSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      // Đang khởi tạo webview — placeholder trống, không flash emoji cũ.
      return const SizedBox.shrink();
    }
    return Webview(
      _controller,
      width: 320,
      height: 380,
    );
  }
}
