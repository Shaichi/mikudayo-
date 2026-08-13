import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/conversation_turn.dart';
import 'live2d_bridge.dart';

/// Điều khiển avatar Miku — Phase 5.
///
/// - Emotion: `setEmotion` → trả qua state, UI (VrmAvatar / emoji) phản ứng.
/// - Lip-sync: `playMouthCues` đặt `speechSeq` + `mouthCues` vào state một lần.
///   Web (VrmAvatar) đọc state và gửi toàn bộ cues lên JS; JS tự nội suy độ mở
///   miệng theo thời gian → Flutter không còn timer 30ms/msg.
class AvatarController extends Notifier<AvatarState> {
  Live2dBridge _bridge = NoopLive2dBridge();

  @override
  AvatarState build() {
    return const AvatarState(emotion: MikuEmotion.neutral);
  }

  void setBridge(Live2dBridge bridge) => _bridge = bridge;

  void setEmotion(MikuEmotion emotion) {
    _bridge.setExpression(emotion);
    state = state.copyWith(emotion: emotion);
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
  });

  final MikuEmotion emotion;

  /// Số thứ tự lần nói — tăng mỗi lần có cues mới (web dùng để chặn nói đè).
  final int speechSeq;

  /// Mouth cues đang chờ web phát (web đọc 1 lần, rồi tự nội suy).
  final List<MouthCue> mouthCues;

  AvatarState copyWith({
    MikuEmotion? emotion,
    int? speechSeq,
    List<MouthCue>? mouthCues,
  }) => AvatarState(
    emotion: emotion ?? this.emotion,
    speechSeq: speechSeq ?? this.speechSeq,
    mouthCues: mouthCues ?? this.mouthCues,
  );
}

final avatarControllerProvider =
    NotifierProvider<AvatarController, AvatarState>(AvatarController.new);
