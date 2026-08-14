import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/avatar_controller.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/conversation_turn.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/api_service.dart';
import '../../data/services/audio_service.dart';
import '../../data/services/speech_recognition_service.dart';

/// Trạng thái pipeline hội thoại — Phase 1–5 (theo mục 5.2 tài liệu).
///
/// idle → recording → recognizing → thinking → synthesizing → playing → idle
/// Error: mic_denied | network_error | gemini_error | tts_error.
enum ConversationPhase {
  idle,
  recording,
  recognizing,
  thinking,
  synthesizing,
  playing,
  error,
}

/// Một lượt trong chuỗi hội thoại trên màn hình.
class Message {
  const Message({required this.kind, required this.text, this.result});

  final MessageKind kind;
  final String text;

  /// `ConversationResult` nếu đây là lượt trả lời của Miku.
  final ConversationResult? result;

  bool get isUser => kind == MessageKind.user;
  bool get isMiku => kind == MessageKind.miku;

  String get displayText => switch (kind) {
    MessageKind.user => text,
    MessageKind.miku => text,
    MessageKind.system => text,
  };
}

enum MessageKind { user, miku, system }

class ConversationState {
  const ConversationState({
    this.phase = ConversationPhase.idle,
    this.messages = const [],
    this.sessionId = '',
    this.errorMessage,
    this.errorCode,
    this.recordingSeconds = 0,
    this.activeReply = '',
  });

  final ConversationPhase phase;
  final List<Message> messages;
  final String sessionId;
  final String? errorMessage;
  final String? errorCode;
  final int recordingSeconds;
  final String activeReply;

  bool get isThinking => phase == ConversationPhase.thinking;
  bool get isRecording => phase == ConversationPhase.recording;
  bool get isBusy =>
      phase == ConversationPhase.thinking ||
      phase == ConversationPhase.recognizing ||
      phase == ConversationPhase.synthesizing ||
      phase == ConversationPhase.playing;

  String get statusLabel => switch (phase) {
    ConversationPhase.idle => 'Miku sẵn sàng!',
    ConversationPhase.recording => 'Đang nghe… $recordingSeconds giây',
    ConversationPhase.recognizing => 'Đang nhận dạng tiếng Nhật…',
    ConversationPhase.thinking => 'Miku đang suy nghĩ…',
    ConversationPhase.synthesizing => 'Đã có câu trả lời · đang tạo giọng…',
    ConversationPhase.playing => 'Đang phát…',
    ConversationPhase.error => errorMessage ?? 'Có lỗi',
  };

  ConversationState copyWith({
    ConversationPhase? phase,
    List<Message>? messages,
    String? sessionId,
    String? errorMessage,
    String? errorCode,
    int? recordingSeconds,
    String? activeReply,
  }) => ConversationState(
    phase: phase ?? this.phase,
    messages: messages ?? this.messages,
    sessionId: sessionId ?? this.sessionId,
    errorMessage: errorMessage ?? this.errorMessage,
    errorCode: errorCode ?? this.errorCode,
    recordingSeconds: recordingSeconds ?? this.recordingSeconds,
    activeReply: activeReply ?? this.activeReply,
  );

  /// Bỏ lỗi, quay về idle mà vẫn giữ tin nhắn.
  ConversationState clearError() => ConversationState(
    phase: ConversationPhase.idle,
    messages: messages,
    sessionId: sessionId,
  );
}

/// ViewModel (Riverpod Notifier) quản lý màn hình hội thoại.
class ConversationViewModel extends Notifier<ConversationState> {
  Future<void>? _voiceStartTask;

  @override
  ConversationState build() => const ConversationState();

  ConversationRepository get _repo => ref.read(conversationRepositoryProvider);
  AppSettings get _settings => ref.read(appSettingsProvider);
  AudioService get _audio => ref.read(audioServiceProvider);
  SpeechRecognitionService get _speech =>
      ref.read(speechRecognitionServiceProvider);

  void addSystemMessage(String text) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        Message(kind: MessageKind.system, text: text),
      ],
    );
  }

  // ---------- Phase 1: text ----------

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isBusy) return;

    state = state.copyWith(
      phase: ConversationPhase.thinking,
      errorMessage: null,
      errorCode: null,
      messages: [
        ...state.messages,
        Message(kind: MessageKind.user, text: trimmed),
      ],
    );

    try {
      final result = await _repo.sendText(
        serverUrl: _settings.serverUrl,
        text: trimmed,
        mode: _settings.mode,
        jlptLevel: _settings.jlptLevel,
        scenario: _settings.scenario,
        sessionId: state.sessionId,
      );
      await _completeTurn(result);
    } on ApiException catch (e) {
      _fail(e.userMessage, e.code);
    } catch (e) {
      _fail('Có lỗi không mong muốn. Vui lòng thử lại.', 'unknown');
    }
  }

  // ---------- Phase 2: voice input ----------

  /// Bắt đầu ghi mic (giữ nút). Trả false nếu bị từ chối quyền.
  Future<bool> startVoiceRecognition() async {
    if (state.phase == ConversationPhase.recording || state.isBusy) {
      return false;
    }

    // Chuyển UI sang recording ngay trước await. Nếu người dùng nhả/chạm nút
    // trong lúc Android đang mở recognizer lần đầu, stop sẽ đợi task này thay
    // vì bị bỏ qua do state vẫn còn idle.
    state = state.copyWith(
      phase: ConversationPhase.recording,
      recordingSeconds: 0,
      errorMessage: null,
      errorCode: null,
    );
    _tickRecording();

    final task = _startVoiceInput();
    _voiceStartTask = task;
    try {
      await task;
      return true;
    } catch (error) {
      if (state.phase == ConversationPhase.recording ||
          state.phase == ConversationPhase.recognizing) {
        _stopTick();
        _fail(_voiceStartError(error), 'speech_unavailable');
      }
      return false;
    } finally {
      if (identical(_voiceStartTask, task)) _voiceStartTask = null;
    }
  }

  Future<void> _startVoiceInput() async {
    if (!Platform.isAndroid) {
      throw StateError('android_only');
    }
    // Nhả audio focus và tránh tiếng Miku còn sót lọt ngược vào recognizer.
    await _audio.stop();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!await _speech.ensureAvailable()) {
      throw StateError('recognizer_unavailable');
    }
    await _speech.startListening();
  }

  String _voiceStartError(Object error) {
    final raw = error.toString();
    if (raw.contains('android_only')) {
      return 'Nhập giọng nói hiện chỉ hỗ trợ Android. Bạn vẫn có thể nhập bằng bàn phím.';
    }
    return 'Không mở được Google Speech Recognition. Hãy kiểm tra quyền micro và dịch vụ Speech Recognition & Synthesis from Google.';
  }

  /// Dừng nhận dạng Google → gửi transcript text → phát câu trả lời.
  Future<void> stopVoiceRecognitionAndSend() async {
    if (state.phase != ConversationPhase.recording) return;
    _stopTick();

    if (!Platform.isAndroid) {
      _fail(
        'Nhập giọng nói hiện chỉ hỗ trợ Android. Bạn vẫn có thể nhập bằng bàn phím.',
        'speech_android_only',
      );
      return;
    }

    final starting = _voiceStartTask;
    if (starting != null) {
      state = state.copyWith(
        phase: ConversationPhase.recognizing,
        recordingSeconds: 0,
      );
      try {
        await starting;
      } catch (_) {
        // startVoiceRecognition hiển thị lỗi cụ thể cho cùng task.
        return;
      }
    }
    await _stopAndroidSpeechAndSend();
  }

  /// Android: Google SpeechRecognizer xử lý mic, backend chỉ nhận text.
  Future<void> _stopAndroidSpeechAndSend() async {
    state = state.copyWith(
      phase: ConversationPhase.recognizing,
      recordingSeconds: 0,
    );

    try {
      final transcript = await _speech.stopListening();
      if (transcript.isEmpty) {
        final detail = _speech.lastErrorMessage;
        _fail(
          detail.isEmpty
              ? 'Không nghe rõ tiếng Nhật. Vui lòng thử lại.'
              : 'Google không nhận dạng được giọng nói ($detail).',
          'speech_not_recognized',
        );
        return;
      }

      state = state.copyWith(
        phase: ConversationPhase.thinking,
        messages: [
          ...state.messages,
          Message(kind: MessageKind.user, text: transcript),
        ],
      );

      final result = await _repo.sendText(
        serverUrl: _settings.serverUrl,
        text: transcript,
        mode: _settings.mode,
        jlptLevel: _settings.jlptLevel,
        scenario: _settings.scenario,
        sessionId: state.sessionId,
      );
      await _completeTurn(result);
    } on ApiException catch (e) {
      _fail(e.userMessage, e.code);
    } catch (_) {
      _fail(
        'Không thể nhận dạng giọng nói. Hãy kiểm tra Google Speech Services và thử lại.',
        'speech_error',
      );
    }
  }

  /// Hủy ghi đang dở.
  Future<void> cancelVoiceRecognition() async {
    _stopTick();
    final starting = _voiceStartTask;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        return;
      }
    }
    if (Platform.isAndroid) await _speech.cancelListening();
    if (state.phase == ConversationPhase.recording) {
      state = state.copyWith(
        phase: ConversationPhase.idle,
        recordingSeconds: 0,
      );
    }
  }

  // ---------- chung: hoàn tất turn + phát audio ----------

  Future<void> _completeTurn(ConversationResult result) async {
    // thinking → synthesizing (sinh audio ở backend) rồi playing.
    state = state.copyWith(
      phase: ConversationPhase.synthesizing,
      sessionId: result.sessionId,
      activeReply: result.replyJa,
    );

    // Cập nhật avatar emotion trước khi phát.
    final avatar = ref.read(avatarControllerProvider.notifier);
    avatar.setEmotion(result.emotion);

    // Text đã hiển thị ngay; đợi job giọng nền rồi stream URL trực tiếp.
    try {
      var audioUrl = result.audioUrl;
      var mouthCues = result.mouthCues;
      if (result.voiceMode == 'pending') {
        final audioStatus = await _repo.waitForAudio(
          serverUrl: _settings.serverUrl,
          turnId: result.turnId,
        );
        audioUrl = audioStatus.audioUrl;
        mouthCues = audioStatus.mouthCues;
      }

      if (audioUrl.isNotEmpty) {
        await _audio.prepareUrl(_settings.serverUrl + audioUrl);
        state = state.copyWith(phase: ConversationPhase.playing);
        final playback = _audio.play();
        await Future.wait([playback, avatar.playMouthCues(mouthCues)]);
      }
    } catch (_) {
      // Audio nền lỗi không làm mất câu trả lời text đã có.
    }
    avatar.stopMouth();

    state = ConversationState(
      phase: ConversationPhase.idle,
      sessionId: result.sessionId,
      messages: [
        ...state.messages,
        Message(kind: MessageKind.miku, text: result.replyJa, result: result),
      ],
      activeReply: '',
    );
  }

  void _fail(String message, String code) {
    state = state.copyWith(
      phase: ConversationPhase.error,
      errorMessage: message,
      errorCode: code,
      messages: [
        ...state.messages,
        Message(kind: MessageKind.system, text: message),
      ],
    );
  }

  void clearError() => state = state.clearError();

  // ---------- timer đếm giây khi recording ----------

  void _stopTick() => _tickTimer?.cancel();
  Timer? _tickTimer;

  void _tickRecording() {
    _stopTick();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.phase == ConversationPhase.recording) {
        state = state.copyWith(recordingSeconds: state.recordingSeconds + 1);
      } else {
        _stopTick();
      }
    });
  }
}

final conversationViewModelProvider =
    NotifierProvider<ConversationViewModel, ConversationState>(
      ConversationViewModel.new,
    );
