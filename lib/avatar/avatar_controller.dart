import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/conversation_turn.dart';
import 'live2d_bridge.dart';

/// Điều khiển avatar Miku — Phase 5.
///
/// - Phase 1–5: emoji cảm xúc + độ mở miệng `mouthOpen` (0..1) cho lip-sync
///   đơn giản, driven bởi `MouthCue` từ backend (RMS 40–60ms).
/// - Khi có SDK Live2D thật: thay `Live2dBridge` (xem `live2d_bridge.dart`),
///   UI phía trên không đổi.
class AvatarController extends Notifier<AvatarState> {
  Live2dBridge _bridge = NoopLive2dBridge();
  Timer? _mouthTimer;
  bool _playingCues = false;

  @override
  AvatarState build() {
    // Dọn timer khi provider bị dispose (Riverpod: ref.onDispose, không phải dispose()).
    ref.onDispose(() {
      _mouthTimer?.cancel();
    });
    return const AvatarState(emotion: MikuEmotion.neutral);
  }

  void setBridge(Live2dBridge bridge) => _bridge = bridge;

  void setEmotion(MikuEmotion emotion) {
    _bridge.setExpression(emotion);
    state = AvatarState(emotion: emotion, mouthOpen: state.mouthOpen);
  }

  void setMouth(double value) {
    if (_playingCues) return; // đang chạy cues thì không cho set tay
    state = state.copyWith(mouthOpen: value.clamp(0.0, 1.0));
  }

  /// Phát lip-sync theo mouth cues (đồng bộ với audio đang phát).
  Future<void> playMouthCues(List<MouthCue> cues) async {
    if (cues.isEmpty) return;
    _playingCues = true;
    _mouthTimer?.cancel();

    _bridge.playMouthCues(cues);
    final stopwatch = Stopwatch()..start();
    var i = 0;
    _mouthTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      final elapsed = stopwatch.elapsedMilliseconds;
      while (i < cues.length - 1 && cues[i + 1].tMs <= elapsed) {
        i++;
      }
      final cue = cues[i];
      state = state.copyWith(mouthOpen: cue.mouth.clamp(0.0, 1.0));
      if (elapsed >= cues.last.tMs) {
        timer.cancel();
        _playingCues = false;
        state = state.copyWith(mouthOpen: 0.05);
      }
    });
  }

  void stopMouth() {
    _mouthTimer?.cancel();
    _playingCues = false;
    state = state.copyWith(mouthOpen: 0.05);
  }
}

/// Trạng thái avatar hiện tại.
class AvatarState {
  const AvatarState({
    this.emotion = MikuEmotion.neutral,
    this.mouthOpen = 0.05,
  });

  final MikuEmotion emotion;
  final double mouthOpen;

  AvatarState copyWith({MikuEmotion? emotion, double? mouthOpen}) =>
      AvatarState(
        emotion: emotion ?? this.emotion,
        mouthOpen: mouthOpen ?? this.mouthOpen,
      );
}

final avatarControllerProvider =
    NotifierProvider<AvatarController, AvatarState>(AvatarController.new);
