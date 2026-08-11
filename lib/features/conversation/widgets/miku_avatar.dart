import 'package:flutter/material.dart';

import '../../../data/models/conversation_turn.dart';

/// Avatar Miku dạng hình tròn + emoji cảm xúc + độ mở miệng.
///
/// Phase 1–5: tĩnh (emoji) + lip-sync đơn giản bằng cách scale emoji theo
/// `mouthOpen` (0..1, từ `MouthCue` của backend). Phase 5+: thay bằng
/// Live2D bridge (xem `lib/avatar/live2d_bridge.dart`).
class MikuAvatar extends StatelessWidget {
  const MikuAvatar({
    super.key,
    this.emotion = MikuEmotion.neutral,
    this.mouthOpen = 0.05,
    this.radius = 56,
  });

  final MikuEmotion emotion;
  final double mouthOpen;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scale emoji theo mouthOpen: 1.0 khi mở, 0.72 khi ngậm miệng.
    final scale = 0.72 + 0.28 * mouthOpen.clamp(0.0, 1.0);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF39C2D7), Color(0xFF00A0B0)],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Text(
            emotion.emoji,
            style: TextStyle(fontSize: radius),
          ),
        ),
      ),
    );
  }
}
