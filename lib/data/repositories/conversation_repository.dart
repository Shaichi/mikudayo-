import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation_turn.dart';
import '../models/session_record.dart';
import '../models/vocabulary_record.dart';
import '../services/api_service.dart';

/// Repository hội thoại — phối hợp settings + api service để gọi backend.
class ConversationRepository {
  ConversationRepository(this._api);

  final ApiService _api;

  /// Gửi text với cài đặt hiện tại.
  Future<ConversationResult> sendText({
    required String serverUrl,
    required String text,
    required String mode,
    required String jlptLevel,
    required String scenario,
    String sessionId = '',
  }) {
    return _api.sendText(
      baseUrl: serverUrl,
      text: text,
      mode: mode,
      jlptLevel: jlptLevel,
      scenario: scenario,
      sessionId: sessionId,
    );
  }

  Future<ConversationAudioStatus> waitForAudio({
    required String serverUrl,
    required String turnId,
  }) {
    return _api.waitForAudio(baseUrl: serverUrl, turnId: turnId);
  }

  Future<List<SessionRecord>> getSessions(String serverUrl) =>
      _api.getSessions(baseUrl: serverUrl);

  Future<List<TurnRecord>> getTurns(String serverUrl, String sessionId) =>
      _api.getTurns(baseUrl: serverUrl, sessionId: sessionId);

  Future<List<VocabularyRecord>> getVocabulary(String serverUrl) =>
      _api.getVocabulary(baseUrl: serverUrl);

  Future<bool> deleteSession(String serverUrl, String sessionId) =>
      _api.deleteSession(baseUrl: serverUrl, sessionId: sessionId);
}

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepository(ref.watch(apiServiceProvider)),
);
