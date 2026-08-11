import 'dart:async';

import '../data/models/conversation_turn.dart';

/// Bridge sang Live2D — Phase 5.
///
/// Live2D chưa có SDK chính thức cho Flutter (mục 10 tài liệu), nên Phase 1–5
/// dùng widget tĩnh + emoji + chuyển động miệng đơn giản (điều chỉnh kích
/// thước hình tròn theo `MouthCue`). File này đóng vai trò *contract*: khi có
/// SDK/bridge thật (web/native), chỉ cần implement `Live2dBridge` và thay thế
/// trong `AvatarController` — UI phía trên không đổi.
abstract class Live2dBridge {
  Future<void> load(String modelPath);
  Future<void> setExpression(MikuEmotion emotion);
  Future<void> playMouthCues(List<MouthCue> cues);
  Future<void> dispose();
}

/// Bridge giả định (default): không làm gì.
class NoopLive2dBridge implements Live2dBridge {
  @override
  Future<void> load(String modelPath) async {}

  @override
  Future<void> setExpression(MikuEmotion emotion) async {}

  @override
  Future<void> playMouthCues(List<MouthCue> cues) async {}

  @override
  Future<void> dispose() async {}
}
