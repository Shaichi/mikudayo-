// test/avatar_gesture_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudayo/avatar/avatar_controller.dart';
import 'package:mikudayo/data/models/conversation_turn.dart';

void main() {
  test('MikuGesture.fromApi parses known names and falls back to none', () {
    expect(MikuGesture.fromApi('wave'), MikuGesture.wave);
    expect(MikuGesture.fromApi('clap'), MikuGesture.clap);
    expect(MikuGesture.fromApi(null), MikuGesture.none);
    expect(MikuGesture.fromApi('backflip'), MikuGesture.none);
  });

  test('ConversationResult parses gesture field', () {
    final result = ConversationResult.fromJson({
      'turn_id': 't',
      'session_id': 's',
      'transcript_ja': 'こんにちは',
      'reply_ja': 'こんばんは！',
      'gesture': 'clap',
    });
    expect(result.gesture, MikuGesture.clap);
  });

  test('AvatarController bumps gestureSeq on play and stop', () {
    final controller = AvatarController();
    controller.build();
    final before = controller.state.gestureSeq;
    controller.playGesture(MikuGesture.wave);
    expect(controller.state.gesture, MikuGesture.wave);
    expect(controller.state.gestureSeq, before + 1);
    controller.stopGesture();
    expect(controller.state.gesture, MikuGesture.none);
    expect(controller.state.gestureSeq, before + 2);
  });

  test('playGesture ignores none', () {
    final controller = AvatarController();
    controller.build();
    final before = controller.state.gestureSeq;
    controller.playGesture(MikuGesture.none);
    expect(controller.state.gestureSeq, before);
  });
}
