import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/conversation_turn.dart';
import 'live2d_bridge.dart';

/// Điều khiển avatar Miku — Phase 5.
///
/// - Emotion: `setEmotion` → trả qua state, UI (Live2dAvatar / emoji) phản ứng.
/// - Lip-sync: `playMouthCues` đặt `speechSeq` + `mouthCues` vào state một lần.
///   Web (Live2dAvatar) đọc state và gửi toàn bộ cues lên JS; JS tự nội suy độ mở
///   miệng theo thời gian → Flutter không còn timer 30ms/msg.
class AvatarController extends Notifier<AvatarState> {
  Live2dBridge _bridge = NoopLive2dBridge();

  /// Standalone fallback: `Notifier.state` requires a provider element, so
  /// tests that call `AvatarController()` + `build()` directly (without a
  /// `ProviderContainer`) get a local state holder instead. In-app, the
  /// provider always supplies `_element`, so Riverpod state is used and this
  /// field is never touched.
  AvatarState? _standaloneState;

  /// `late final _element` throws a private `LateInitializationError`
  /// ("Field '_element' has not been initialized") when the notifier is used
  /// outside a provider. Detect exactly that error; rethrow anything else.
  static bool _isMissingElement(Object e) =>
      e is Error && e.toString().contains('has not been initialized');

  @override
  AvatarState get state {
    try {
      return super.state;
    } catch (e) {
      if (_isMissingElement(e)) return _standaloneState ??= build();
      rethrow;
    }
  }

  @override
  set state(AvatarState value) {
    try {
      super.state = value;
    } catch (e) {
      if (_isMissingElement(e)) {
        _standaloneState = value;
        return;
      }
      rethrow;
    }
  }

  @override
  AvatarState build() {
    return const AvatarState(emotion: MikuEmotion.neutral);
  }

  void setBridge(Live2dBridge bridge) => _bridge = bridge;

  void setEmotion(MikuEmotion emotion) {
    _bridge.setExpression(emotion);
    state = state.copyWith(emotion: emotion);
  }

  void playGesture(MikuGesture gesture) {
    if (gesture == MikuGesture.none) return;
    state = state.copyWith(gesture: gesture, gestureSeq: state.gestureSeq + 1);
  }

  void stopGesture() {
    state = state.copyWith(gesture: MikuGesture.none, gestureSeq: state.gestureSeq + 1);
  }

  /// Phát lip-sync theo mouth cues. Chỉ đặt state 1 lần; web/UI tự chạy.
  Future<void> playMouthCues(List<MouthCue> cues) async {
    if (cues.isEmpty) return;
    state = AvatarState(
      emotion: state.emotion,
      speechSeq: state.speechSeq + 1,
      mouthCues: List.of(cues),
    );
  }

  void stopMouth() {
    state = state.copyWith(speechSeq: state.speechSeq + 1, mouthCues: const []);
  }
}

/// Trạng thái avatar hiện tại.
class AvatarState {
  const AvatarState({
    this.emotion = MikuEmotion.neutral,
    this.speechSeq = 0,
    this.mouthCues = const [],
    this.gesture = MikuGesture.none,
    this.gestureSeq = 0,
  });

  final MikuEmotion emotion;

  /// Số thứ tự lần nói — tăng mỗi lần có cues mới (web dùng để chặn nói đè).
  final int speechSeq;

  /// Mouth cues đang chờ web phát (web đọc 1 lần, rồi tự nội suy).
  final List<MouthCue> mouthCues;

  final MikuGesture gesture;
  final int gestureSeq;

  AvatarState copyWith({
    MikuEmotion? emotion,
    int? speechSeq,
    List<MouthCue>? mouthCues,
    MikuGesture? gesture,
    int? gestureSeq,
  }) => AvatarState(
    emotion: emotion ?? this.emotion,
    speechSeq: speechSeq ?? this.speechSeq,
    mouthCues: mouthCues ?? this.mouthCues,
    gesture: gesture ?? this.gesture,
    gestureSeq: gestureSeq ?? this.gestureSeq,
  );
}

final avatarControllerProvider =
    NotifierProvider<AvatarController, AvatarState>(AvatarController.new);
