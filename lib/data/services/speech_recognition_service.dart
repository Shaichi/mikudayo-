import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Nhận dạng tiếng Nhật bằng Google SpeechRecognizer trên Android.
///
/// Audio được Google xử lý trực tiếp trên điện thoại; backend Miku chỉ nhận
/// transcript text. Android có thể tự kết thúc một lượt nghe sau khoảng lặng,
/// nên service tự mở lượt kế tiếp và ghép các đoạn trong khi người dùng vẫn
/// đang ở trạng thái ghi âm.
class SpeechRecognitionService {
  SpeechRecognitionService() : _speech = SpeechToText();

  final SpeechToText _speech;
  final _transcript = TranscriptAssembler();
  bool _initialized = false;
  bool _keepListening = false;
  int _listenGeneration = 0;
  SpeechRecognitionError? _lastError;
  Completer<void>? _firstNonEmptyResult;
  DateTime? _listenStartedAt;
  Future<dynamic>? _listenTask;
  Timer? _restartTimer;

  static const _japaneseLocaleId = 'ja-JP';
  static const _initialPauseFor = Duration(seconds: 5);
  static const _minimumListenDuration = Duration(milliseconds: 800);
  static const _lateResultWait = Duration(milliseconds: 1800);
  static const _restartDelay = Duration(milliseconds: 500);

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

  Future<void> startListening() async {
    if (!await ensureAvailable()) {
      throw StateError('Speech recognition không khả dụng trên thiết bị.');
    }

    _restartTimer?.cancel();
    _transcript.clear();
    _lastError = null;
    _firstNonEmptyResult = Completer<void>();
    _listenStartedAt = DateTime.now();
    _keepListening = true;
    _listenGeneration += 1;
    debugPrint('[STT] listen locale=$_japaneseLocaleId');

    await _startRecognizerPass(_listenGeneration);
    if (!_speech.isListening && _lastError != null) {
      throw StateError(_lastError!.errorMsg);
    }
    debugPrint('[STT] listening=${_speech.isListening}');
  }

  Future<void> _startRecognizerPass(int generation) async {
    if (!_keepListening || generation != _listenGeneration) return;

    final task = _speech
        .listen(
          onResult: _onResult,
          listenOptions: SpeechListenOptions(
            localeId: _japaneseLocaleId,
            listenFor: const Duration(seconds: 60),
            pauseFor: _initialPauseFor,
            partialResults: true,
            // no-match after one pause is not fatal while recording continues.
            cancelOnError: false,
            onDevice: false,
            listenMode: ListenMode.dictation,
          ),
        )
        .timeout(const Duration(seconds: 8));
    _listenTask = task;
    try {
      await task;
    } finally {
      if (identical(_listenTask, task)) _listenTask = null;
    }

    // stopListening may have been tapped while Android was opening the mic.
    if ((!_keepListening || generation != _listenGeneration) &&
        _speech.isListening) {
      await _speech.stop();
    }
  }

  /// Dừng Google recognizer, đợi callback cuối và trả về toàn bộ các đoạn.
  Future<String> stopListening() async {
    debugPrint('[STT] stop requested, listening=${_speech.isListening}');
    _keepListening = false;
    _listenGeneration += 1;
    _restartTimer?.cancel();

    final opening = _listenTask;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {
        // Vẫn giữ transcript của các pass trước nếu pass mới mở thất bại.
      }
    }

    // Chống tap kép làm recognizer vừa mở đã bị đóng ngay.
    final startedAt = _listenStartedAt;
    if (_speech.isListening && startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minimumListenDuration - elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }

    if (_speech.isListening) await _speech.stop();

    if (_transcript.text.isEmpty) {
      try {
        await _firstNonEmptyResult?.future.timeout(_lateResultWait);
      } on TimeoutException {
        // UI sẽ báo không nhận dạng được nếu thực sự không có chữ.
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _listenStartedAt = null;
    _transcript.finishPass();
    final result = _transcript.text;
    debugPrint('[STT] transcript="$result"');
    return result;
  }

  Future<void> cancelListening() async {
    _keepListening = false;
    _listenGeneration += 1;
    _restartTimer?.cancel();
    if (_speech.isListening) await _speech.cancel();
    _listenStartedAt = null;
  }

  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords;
    if (words.trim().isNotEmpty) {
      _transcript.add(words, isFinal: result.finalResult);
      _lastError = null;
      final completer = _firstNonEmptyResult;
      if (completer != null && !completer.isCompleted) completer.complete();
    } else {
      _transcript.markBoundary();
    }
    debugPrint(
      '[STT] result final=${result.finalResult} text="$words" '
      'combined="${_transcript.text}"',
    );
  }

  void _onError(SpeechRecognitionError error) {
    final transientNoMatch =
        error.errorMsg == 'error_no_match' && _keepListening;
    if (!transientNoMatch) {
      _lastError = error;
      if (error.permanent) _keepListening = false;
    }
    debugPrint('[STT] error=${error.errorMsg} permanent=${error.permanent}');
  }

  void _onStatus(String status) {
    debugPrint('[STT] status=$status');
    if (status != 'done' && status != 'notListening') return;
    if (!_keepListening) return;

    // Google có thể tự đóng sau khoảng lặng dù pauseFor dài hơn. Lưu đoạn đã
    // nhận và mở pass kế tiếp nếu người dùng chưa bấm dừng.
    _transcript.finishPass();
    final generation = _listenGeneration;
    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, () async {
      if (!_keepListening || generation != _listenGeneration) return;
      if (_speech.isListening) return;
      debugPrint('[STT] restarting Google recognizer after early done');
      try {
        await _startRecognizerPass(generation);
      } catch (error) {
        debugPrint('[STT] restart failed: $error');
      }
    });
  }
}

/// Ghép các hypothesis/đoạn độc lập mà Google trả trong một lần người dùng
/// nhấn mic. Đặc biệt không để callback ngắn cuối cùng xóa cả câu trước đó.
@visibleForTesting
class TranscriptAssembler {
  final List<String> _completed = [];
  String _current = '';
  bool _boundarySeen = false;

  String get text => [
    ..._completed,
    if (_current.isNotEmpty) _current,
  ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  void clear() {
    _completed.clear();
    _current = '';
    _boundarySeen = false;
  }

  void markBoundary() {
    if (_current.isNotEmpty) _boundarySeen = true;
  }

  void add(String rawValue, {required bool isFinal}) {
    final explicitBoundary =
        rawValue.isNotEmpty && rawValue.trimLeft() != rawValue;
    final words = rawValue.trim();
    if (words.isEmpty) {
      markBoundary();
      return;
    }

    // Callback final của pass cũ có thể đến muộn sau khi pass mới đã mở.
    if (_current.isEmpty && _completed.isNotEmpty && _completed.last == words) {
      return;
    }

    if (_current.isEmpty) {
      _current = words;
    } else if (words == _current || words.startsWith(_current)) {
      _current = words;
    } else if (_current.startsWith(words)) {
      // Không để hypothesis tạm thời ngắn hơn xóa bản tốt hơn.
    } else if (explicitBoundary ||
        (_boundarySeen && !_looksLikeExpandedRevision(_current, words))) {
      _commitCurrent();
      _current = words;
    } else {
      // Google sửa mạnh hypothesis trong cùng một cụm nói.
      _current = words;
    }

    _boundarySeen = false;
    if (isFinal) _commitCurrent();
  }

  void finishPass() {
    _commitCurrent();
    _boundarySeen = false;
  }

  bool _looksLikeExpandedRevision(String previous, String next) {
    if (next.length < previous.length * 2 || previous.isEmpty || next.isEmpty) {
      return false;
    }
    // Ví dụ Google sửa filler "えーと" thành "えっとバイクを使います".
    return previous[0] == next[0];
  }

  void _commitCurrent() {
    final value = _current.trim();
    if (value.isNotEmpty && (_completed.isEmpty || _completed.last != value)) {
      _completed.add(value);
    }
    _current = '';
  }
}

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>(
  (ref) => SpeechRecognitionService(),
);
