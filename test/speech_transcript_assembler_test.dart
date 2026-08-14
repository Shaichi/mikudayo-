import 'package:flutter_test/flutter_test.dart';
import 'package:mikudayo/data/services/speech_recognition_service.dart';

void main() {
  test('keeps every phrase from a long Google dictation result', () {
    final transcript = TranscriptAssembler();

    transcript.add('すいません 分かりません', isFinal: false);
    transcript.markBoundary();
    transcript.add(' 簡単に', isFinal: false);
    transcript.markBoundary();
    transcript.add('してください', isFinal: false);
    transcript.add('してください', isFinal: true);

    expect(transcript.text, 'すいません 分かりません 簡単に してください');
  });

  test('replaces a short filler hypothesis with its expanded revision', () {
    final transcript = TranscriptAssembler();

    transcript.add('えーと', isFinal: false);
    transcript.markBoundary();
    transcript.add('えっとバイクを使います', isFinal: false);
    transcript.add('えっとバイクを使います', isFinal: true);

    expect(transcript.text, 'えっとバイクを使います');
  });

  test('ignores a delayed duplicate final result after pass restart', () {
    final transcript = TranscriptAssembler();

    transcript.add('最初の文です', isFinal: false);
    transcript.finishPass();
    transcript.add('最初の文です', isFinal: true);
    transcript.add('次の文です', isFinal: true);

    expect(transcript.text, '最初の文です 次の文です');
  });
}
