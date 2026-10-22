import 'package:flutter_test/flutter_test.dart';

import 'package:mikudayo/data/models/conversation_turn.dart';

void main() {
  test('parse audio background status with mouth cues', () {
    final status = ConversationAudioStatus.fromJson({
      'status': 'ready',
      'audio_url': '/v1/audio/turn-1',
      'voice_mode': 'fish_audio',
      'mouth_cues': [
        {'t_ms': 0, 'mouth': 0.2},
        {'t_ms': 50, 'mouth': 0.8},
      ],
      'timing_ms': {'tts_ms': 2800},
    });

    expect(status.isReady, isTrue);
    expect(status.audioUrl, '/v1/audio/turn-1');
    expect(status.mouthCues, hasLength(2));
    expect(status.timingMs['tts_ms'], 2800);
  });
}
