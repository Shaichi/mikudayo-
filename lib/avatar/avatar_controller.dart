import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/conversation_turn.dart';

/// Điều khiển avatar Miku.
///
/// - Phase 1: chỉ ánh xạ cảm xúc → emoji/icon (chưa có Live2D).
/// - Phase 5: sẽ thay bằng bridge sang Live2D, khớp chuyển động miệng theo
///   `MouthCue` và biểu cảm theo `MikuEmotion`.
class AvatarController extends Notifier<AvatarState> {
  @override
  AvatarState build() => const AvatarState(emotion: MikuEmotion.neutral);

  void setEmotion(MikuEmotion emotion) => state = AvatarState(emotion: emotion);
}

/// Trạng thái avatar hiện tại.
class AvatarState {
  const AvatarState({this.emotion = MikuEmotion.neutral});

  final MikuEmotion emotion;

  AvatarState copyWith({MikuEmotion? emotion}) =>
      AvatarState(emotion: emotion ?? this.emotion);
}

final avatarControllerProvider =
    NotifierProvider<AvatarController, AvatarState>(AvatarController.new);
