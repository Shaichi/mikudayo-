import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/avatar_controller.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/conversation_turn.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/api_service.dart';
import '../../data/services/audio_service.dart';

/// Trạng thái pipeline hội thoại — Phase 1–5 (theo mục 5.2 tài liệu).
///
/// id→ recording → uploading → thinking → synthesizing → playing → idle
/// Error: mic_denied | network_error | gemini_error | tts_error | rvc_fallback.
enum ConversationPhase {
  idle,
  recording,
  uploading,
  thinking,
  synthesizing,
  playing,
  error,
}

/// Một lượt trong chuỗi hội thoại trên màn hình.
class Message {
  const Message({
    required this.kind,
    required this.text,
    this.result,
  });

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
  });

  final ConversationPhase phase;
  final List<Message> messages;
  final String sessionId;
  final String? errorMessage;
  final String? errorCode;
  final int recordingSeconds;

  bool get isThinking => phase == ConversationPhase.thinking;
  bool get isRecording => phase == ConversationPhase.recording;
  bool get isBusy =>
      phase == ConversationPhase.thinking ||
      phase == ConversationPhase.uploading ||
      phase == ConversationPhase.synthesizing ||
      phase == ConversationPhase.playing;

  String get statusLabel => switch (phase) {
        ConversationPhase.idle => 'Miku sẵn sàng!',
        ConversationPhase.recording => 'Đang ghi âm… $recordingSeconds giây',
        ConversationPhase.uploading => 'Đang tải audio…',
        ConversationPhase.thinking => 'Miku đang suy nghĩ…',
        ConversationPhase.synthesizing => 'Miku đang nói…',
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
  }) =>
      ConversationState(
        phase: phase ?? this.phase,
        messages: messages ?? this.messages,
        sessionId: sessionId ?? this.sessionId,
        errorMessage: errorMessage ?? this.errorMessage,
        errorCode: errorCode ?? this.errorCode,
        recordingSeconds: recordingSeconds ?? this.recordingSeconds,
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
  @override
  ConversationState build() => const ConversationState();

  ConversationRepository get _repo => ref.read(conversationRepositoryProvider);
  AppSettings get _settings => ref.read(appSettingsProvider);
  AudioService get _audio => ref.read(audioServiceProvider);

  void addSystemMessage(String text) {
    state = state.copyWith(
      messages: [...state.messages, Message(kind: MessageKind.system, text: text)],
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
      messages: [...state.messages, Message(kind: MessageKind.user, text: trimmed)],
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
  Future<bool> startRecording() async {
    if (state.isBusy) return false;
    final ok = await _audio.ensurePermission();
    if (!ok) {
      _fail('Không có quyền micro. Hãy cấp quyền trong hệ điều hành.', 'mic_denied');
      return false;
    }
    try {
      await _audio.startRecording();
      state = state.copyWith(
        phase: ConversationPhase.recording,
        recordingSeconds: 0,
        errorMessage: null,
        errorCode: null,
      );
      // Bắt đầu đếm giây hiển thị.
      _tickRecording();
      return true;
    } catch (_) {
      _fail('Không khởi động được micro.', 'mic_denied');
      return false;
    }
  }

  /// Dừng ghi → upload → thinking → synthesize → playing.
  Future<void> stopRecordingAndSend() async {
    if (state.phase != ConversationPhase.recording) return;
    _stopTick();

    List<int> audioBytes;
    try {
      audioBytes = await _audio.stopRecording();
    } catch (_) {
      _fail('Không lấy được audio. Vui lòng thử lại.', 'mic_denied');
      return;
    }
    if (audioBytes.isEmpty) {
      state = state.copyWith(phase: ConversationPhase.idle, recordingSeconds: 0);
      return;
    }

    // uploading
    state = state.copyWith(
      phase: ConversationPhase.uploading,
      messages: [
        ...state.messages,
        Message(kind: MessageKind.user, text: '🎤 (thoại)'),
      ],
    );

    try {
      final result = await _repo.sendAudio(
        serverUrl: _settings.serverUrl,
        audioBytes: audioBytes,
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

  /// Hủy ghi đang dở.
  Future<void> cancelRecording() async {
    _stopTick();
    await _audio.cancelRecording();
    if (state.phase == ConversationPhase.recording) {
      state = state.copyWith(phase: ConversationPhase.idle, recordingSeconds: 0);
    }
  }

  // ---------- chung: hoàn tất turn + phát audio ----------

  Future<void> _completeTurn(ConversationResult result) async {
    // thinking → synthesizing (sinh audio ở backend) rồi playing.
    state = state.copyWith(
      phase: ConversationPhase.synthesizing,
      sessionId: result.sessionId,
    );

    // Cập nhật avatar emotion trước khi phát.
    final avatar = ref.read(avatarControllerProvider.notifier);
    avatar.setEmotion(result.emotion);

    // Nếu có audio_url → tải và phát (Phase 3+), lip-sync theo mouth cues.
    if (result.audioUrl.isNotEmpty) {
      try {
        final bytes =
            await _audio.fetchAudio(_settings.serverUrl + result.audioUrl);
        state = state.copyWith(phase: ConversationPhase.playing);
        final playback = _audio.playBytes(bytes);
        // Phát lip-sync song song với audio.
        await Future.wait([
          playback,
          avatar.playMouthCues(result.mouthCues),
        ]);
      } catch (_) {
        // Không phát được audio không phải lỗi chí mạng — vẫn hiển thị reply.
      }
    }
    avatar.stopMouth();

    state = ConversationState(
      phase: ConversationPhase.idle,
      sessionId: result.sessionId,
      messages: [...state.messages, Message(kind: MessageKind.miku, text: result.replyJa, result: result)],
    );
  }

  void _fail(String message, String code) {
    state = state.copyWith(
      phase: ConversationPhase.error,
      errorMessage: message,
      errorCode: code,
      messages: [...state.messages, Message(kind: MessageKind.system, text: message)],
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
