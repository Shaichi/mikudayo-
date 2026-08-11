import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/conversation_turn.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/api_service.dart';

/// Trạng thái pipeline hội thoại — Phase 1 tối giản.
///
/// Phiên bản đầy đủ (Phase 2–6) sẽ có: idle → recording → uploading → thinking
/// → synthesizing → playing → idle. Phase 1 chỉ dùng idle → thinking → idle | error.
enum ConversationPhase { idle, thinking, error }

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
  });

  final ConversationPhase phase;
  final List<Message> messages;
  final String sessionId;
  final String? errorMessage;
  final String? errorCode;

  bool get isThinking => phase == ConversationPhase.thinking;

  ConversationState copyWith({
    ConversationPhase? phase,
    List<Message>? messages,
    String? sessionId,
    String? errorMessage,
    String? errorCode,
  }) =>
      ConversationState(
        phase: phase ?? this.phase,
        messages: messages ?? this.messages,
        sessionId: sessionId ?? this.sessionId,
        errorMessage: errorMessage ?? this.errorMessage,
        errorCode: errorCode ?? this.errorCode,
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

  void addSystemMessage(String text) {
    state = state.copyWith(
      messages: [...state.messages, Message(kind: MessageKind.system, text: text)],
    );
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isThinking) return;

    // 1. idle → thinking (hiển thị "Miku đang suy nghĩ…")
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

      // 2. thinking → idle, thêm reply của Miku + giữ session.
      state = ConversationState(
        phase: ConversationPhase.idle,
        sessionId: result.sessionId,
        messages: [...state.messages, Message(kind: MessageKind.miku, text: result.replyJa, result: result)],
      );
    } on ApiException catch (e) {
      // 3. thinking → error (hiển thị message thân thiện).
      state = state.copyWith(
        phase: ConversationPhase.error,
        errorMessage: e.userMessage,
        errorCode: e.code,
        messages: [...state.messages, Message(kind: MessageKind.system, text: e.userMessage)],
      );
    } catch (e) {
      state = state.copyWith(
        phase: ConversationPhase.error,
        errorMessage: 'Có lỗi không mong muốn. Vui lòng thử lại.',
        errorCode: 'unknown',
        messages: [
          ...state.messages,
          Message(kind: MessageKind.system, text: 'Có lỗi không mong muốn. Vui lòng thử lại.'),
        ],
      );
    }
  }

  void clearError() => state = state.clearError();
}

final conversationViewModelProvider =
    NotifierProvider<ConversationViewModel, ConversationState>(
  ConversationViewModel.new,
);
