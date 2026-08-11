import 'package:flutter/material.dart';

import '../../../data/models/conversation_turn.dart';

/// Chip hiển thị một từ vựng trong lượt trả lời của Miku.
class VocabChip extends StatelessWidget {
  const VocabChip({super.key, required this.item});

  final VocabItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.word,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (item.reading.isNotEmpty)
            Text(
              item.reading,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (item.meaningVi.isNotEmpty)
            Text(
              item.meaningVi,
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
        ],
      ),
    );
  }
}
