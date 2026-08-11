import 'package:flutter/material.dart';

import '../../../data/models/conversation_turn.dart';

/// Avatar Miku dạng hình tròn + emoji cảm xúc lớn.
///
/// Phase 1: tĩnh (emoji). Phase 5: thay bằng Live2D bridge.
class MikuAvatar extends StatelessWidget {
  const MikuAvatar({
    super.key,
    this.emotion = MikuEmotion.neutral,
    this.radius = 56,
  });

  final MikuEmotion emotion;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
        child: Text(
          emotion.emoji,
          style: TextStyle(fontSize: radius),
        ),
      ),
    );
  }
}
