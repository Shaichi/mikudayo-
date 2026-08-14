// Kiểm thử tích hợp ApiService với backend thật (cần backend đang chạy mock).
//
// Chạy:  flutter test test/api_service_live_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:mikudayo/data/services/api_service.dart';

const _base = 'http://127.0.0.1:8000';

void main() {
  final api = ApiService();

  test('sendText gửi tiếng Nhật và parse kết quả', () async {
    final result = await api.sendText(
      baseUrl: _base,
      text: 'こんにちは',
      mode: 'free_talk',
      jlptLevel: 'N5',
    );

    expect(result.turnId, isNotEmpty);
    expect(result.sessionId, isNotEmpty);
    expect(result.replyJa, isNotEmpty);
    expect(result.transcriptJa, 'こんにちは');
    expect(result.vocabulary, isNotEmpty);
    expect(result.voiceMode, 'pending');
    expect(result.audioUrl, isEmpty);
    final audio = await api.waitForAudio(baseUrl: _base, turnId: result.turnId);
    expect(audio.isReady, isTrue);
    expect(audio.audioUrl, isNotEmpty);
    // ignore: avoid_print
    print(
      'reply: ${result.replyJa} | emotion: ${result.emotion} | audio: ${audio.audioUrl}',
    );
  });

  test('sendText với correction mode trả explanation', () async {
    // Dùng câu thật sự sai ngữ pháp để Gemini phải sửa.
    // (Câu '私はベトナム人です' không sai → Gemini không sửa là hành vi đúng.)
    final result = await api.sendText(
      baseUrl: _base,
      text: 'きょうはなんですか',
      mode: 'correction',
      jlptLevel: 'N5',
    );
    expect(result.explanationVi, isNotNull);
  });
}
