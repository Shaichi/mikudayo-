// test/gesture_trigger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudayo/data/models/conversation_turn.dart';
import 'package:mikudayo/features/conversation/conversation_view_model.dart';

ConversationResult _make(MikuEmotion emotion, MikuGesture gesture) =>
    ConversationResult(
      turnId: 't',
      sessionId: 's',
      transcriptJa: 'a',
      replyJa: 'b',
      emotion: emotion,
      gesture: gesture,
    );

void main() {
  test('gestureFor prefers Gemini gesture over emotion fallback', () {
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.happy, MikuGesture.nod)),
      MikuGesture.nod,
    );
  });

  test('gestureFor falls back by emotion when Gemini says none', () {
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.happy, MikuGesture.none)),
      MikuGesture.clap,
    );
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.excited, MikuGesture.none)),
      MikuGesture.clap,
    );
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.sad, MikuGesture.none)),
      MikuGesture.sad,
    );
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.thinking, MikuGesture.none)),
      MikuGesture.thinking,
    );
    expect(
      ConversationViewModel.gestureFor(_make(MikuEmotion.neutral, MikuGesture.none)),
      MikuGesture.none,
    );
  });
}
