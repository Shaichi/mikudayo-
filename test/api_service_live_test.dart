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
    expect(result.audioUrl, isNotEmpty);
    // ignore: avoid_print
    print('reply: ${result.replyJa} | emotion: ${result.emotion} | audio: ${result.audioUrl}');
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

  test('sendAudio upload wav → trả transcript + reply + mouth cues', () async {
    // Tạo một WAV nhỏ hợp lệ (0.1s silence 16kHz).
    final wav = _makeTinyWav();
    final result = await api.sendAudio(
      baseUrl: _base,
      audioBytes: wav,
      mode: 'free_talk',
      jlptLevel: 'N5',
    );

    expect(result.turnId, isNotEmpty);
    expect(result.replyJa, isNotEmpty);
    expect(result.audioUrl, isNotEmpty);
    expect(result.mouthCues, isNotEmpty);
    // ignore: avoid_print
    print('audio upload: transcript="${result.transcriptJa}" cues=${result.mouthCues.length}');
  });
}

/// Tạo WAV PCM 16-bit 16kHz mono, 0.1s.
List<int> _makeTinyWav() {
  const rate = 16000;
  const frames = rate ~/ 10; // 0.1s
  final data = <int>[];
  // RIFF header
  List<int> int32(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
  List<int> int16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
  final dataSize = frames * 2;
  data.addAll('RIFF'.codeUnits);
  data.addAll(int32(36 + dataSize));
  data.addAll('WAVE'.codeUnits);
  data.addAll('fmt '.codeUnits);
  data.addAll(int32(16));
  data.addAll(int16(1)); // PCM
  data.addAll(int16(1)); // mono
  data.addAll(int32(rate));
  data.addAll(int32(rate * 2)); // byte rate
  data.addAll(int16(2)); // block align
  data.addAll(int16(16)); // bits
  data.addAll('data'.codeUnits);
  data.addAll(int32(dataSize));
  for (var i = 0; i < frames; i++) {
    data.addAll(int16(0)); // silence
  }
  return data;
}
