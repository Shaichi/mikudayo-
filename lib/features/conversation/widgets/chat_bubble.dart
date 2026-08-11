import 'package:flutter/material.dart';

import '../../../data/models/conversation_turn.dart';
import 'vocab_chip.dart';

/// Bubble hội thoại cho tin nhắn của người học (user) hoặc Miku.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.isUser,
    required this.text,
    this.result,
  });

  final bool isUser;
  final String text;

  /// Kết quả hội thoại (chỉ có khi là tin nhắn của Miku) — hiển thị
  /// transcript, correction, explanation, emotion, vocabulary.
  final ConversationResult? result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      decoration: BoxDecoration(
        color: isUser ? scheme.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? 16 : 4),
          topRight: Radius.circular(isUser ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isUser ? Colors.white : scheme.onSurface,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          if (result != null) ..._buildResultDetail(scheme),
        ],
      ),
    );

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bubble],
    );
  }

  List<Widget> _buildResultDetail(ColorScheme scheme) {
    final r = result!;
    final widgets = <Widget>[];

    // Emoji badge cảm xúc (góc trên, đằng sau bubble).
    // Hiển thị thành dòng nhỏ kèm nhãn.
    if (r.emotion != MikuEmotion.neutral) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.emotion.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                r.emotion.label,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Sửa lỗi + giải thích tiếng Việt (khi có).
    final correction = r.correctionJa;
    final explanation = r.explanationVi;
    if ((correction != null && correction.isNotEmpty) ||
        (explanation != null && explanation.isNotEmpty)) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (correction != null && correction.isNotEmpty) ...[
                const Text(
                  '✨ Câu sửa',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  correction,
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ],
              if (explanation != null && explanation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Vocabulary chips.
    if (r.vocabulary.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final v in r.vocabulary) VocabChip(item: v)],
          ),
        ),
      );
    }

    return widgets;
  }
}
