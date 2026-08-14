import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Nhận dạng giọng nói bằng dịch vụ SpeechRecognizer của Android.
///
/// Android/Google xử lý audio trực tiếp. Ứng dụng chỉ nhận chuỗi kết quả và
/// không tạo hoặc gửi file ghi âm tới backend Miku.
class SpeechRecognitionService {
  SpeechRecognitionService() : _speech = SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  String _transcript = '';
  SpeechRecognitionError? _lastError;
  Completer<void>? _firstNonEmptyResult;
  DateTime? _listenStartedAt;
  static const _japaneseLocaleId = 'ja-JP';
  static const _initialPauseFor = Duration(seconds: 5);
  static const _minimumListenDuration = Duration(milliseconds: 800);
  static const _lateResultWait = Duration(milliseconds: 1800);

  String get lastErrorMessage => _lastError?.errorMsg ?? '';

  Future<bool> ensureAvailable() async {
    if (_initialized) return true;
    debugPrint('[STT] initialize Android SpeechRecognizer');
    _initialized = await _speech
        .initialize(
          onError: _onError,
          onStatus: _onStatus,
          debugLogging: kDebugMode,
          finalTimeout: const Duration(seconds: 3),
          options: [SpeechToText.androidNoBluetooth],
        )
        .timeout(const Duration(seconds: 8));
    debugPrint('[STT] initialized=$_initialized');
    return _initialized;
  }

  /// Bắt đầu một lượt nghe ngắn, ưu tiên tiếng Nhật chuẩn Nhật Bản.
  Future<void> startListening() async {
    if (!await ensureAvailable()) {
      throw StateError('Speech recognition không khả dụng trên thiết bị.');
    }

    _transcript = '';
    _lastError = null;
    _firstNonEmptyResult = Completer<void>();
    _listenStartedAt = DateTime.now();
    debugPrint('[STT] listen locale=$_japaneseLocaleId');

    await _speech
        .listen(
          onResult: _onResult,
          listenOptions: SpeechListenOptions(
            localeId: _japaneseLocaleId,
            listenFor: const Duration(seconds: 60),
            // speech_to_text 7.4 tôn trọng pauseFor trên Android. Cho người
            // dùng đủ thời gian bắt đầu nói và ngắt hơi tự nhiên.
            pauseFor: _initialPauseFor,
            partialResults: true,
            cancelOnError: true,
            onDevice: false,
            listenMode: ListenMode.dictation,
          ),
        )
        .timeout(const Duration(seconds: 8));

    if (!_speech.isListening && _lastError != null) {
      throw StateError(_lastError!.errorMsg);
    }
    debugPrint('[STT] listening=${_speech.isListening}');
  }

  /// Dừng nghe, đợi kết quả cuối và chỉ trả về văn bản.
  Future<String> stopListening() async {
    debugPrint('[STT] stop requested, listening=${_speech.isListening}');

    // Chống thao tác tap kép làm recognizer vừa mở đã bị đóng ngay. Log máy
    // thật từng ghi nhận một session chỉ kéo dài 46 ms.
    final startedAt = _listenStartedAt;
    if (_speech.isListening && startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minimumListenDuration - elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }

    if (_speech.isListening) await _speech.stop();

    // Android có thể phát status "done" trước callback kết quả. Nếu chưa có
    // chữ nào, chờ callback không rỗng thay vì kết luận no-match ngay.
    if (_transcript.trim().isEmpty) {
      try {
        await _firstNonEmptyResult?.future.timeout(_lateResultWait);
      } on TimeoutException {
        // Không có kết quả muộn; trả rỗng để UI hiển thị lời nhắc thử lại.
      }
    } else {
      // Cho kết quả partial cuối có cơ hội được tinh chỉnh sau stop.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _listenStartedAt = null;
    final result = _transcript.trim();
    debugPrint('[STT] transcript="$result"');
    return result;
  }

  Future<void> cancelListening() async {
    if (_speech.isListening) await _speech.cancel();
    _listenStartedAt = null;
  }

  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    // Google đôi lúc gửi callback rỗng sau một partial result hợp lệ. Không
    // được xóa câu đã nhận dạng tốt gần nhất.
    if (words.isNotEmpty) {
      _transcript = words;
      final completer = _firstNonEmptyResult;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
    debugPrint(
      '[STT] result final=${result.finalResult} text="${result.recognizedWords}"',
    );
  }

  void _onError(SpeechRecognitionError error) {
    _lastError = error;
    debugPrint('[STT] error=${error.errorMsg} permanent=${error.permanent}');
  }

  void _onStatus(String status) {
    debugPrint('[STT] status=$status');
  }
}

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>(
  (ref) => SpeechRecognitionService(),
);
