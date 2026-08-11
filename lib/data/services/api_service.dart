import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/server_config.dart';
import '../../core/errors/api_exception.dart';
import '../models/conversation_turn.dart';
import '../repositories/settings_repository.dart';
import '../models/session_record.dart';
import '../models/vocabulary_record.dart';

/// Dịch vụ gọi API FastAPI backend.
///
/// - POST /v1/conversation/turn  — gửi text (Phase 1), parse ConversationResult.
/// - GET  /v1/sessions            — danh sách phiên.
/// - GET  /v1/sessions/{id}/turns — lượt hội thoại của phiên.
/// - GET  /v1/vocabulary          — sổ từ vựng.
/// - DELETE /v1/sessions/{id}     — xóa phiên.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String baseUrl, String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers() => {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'Accept': 'application/json',
      };

  Future<Map<String, dynamic>> _decode(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException.invalidResponse();
      }
    }
    String? detail;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      detail = (body as Map<String, dynamic>)['detail'] as String?;
    } catch (_) {}
    throw ApiException.server(status: res.statusCode, detail: detail);
  }

  Future<List<Map<String, dynamic>>> _decodeList(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (_) {
        throw ApiException.invalidResponse();
      }
    }
    throw ApiException.server(status: res.statusCode);
  }

  /// Gửi một lượt hội thoại dạng text → trả về `ConversationResult`.
  Future<ConversationResult> sendText({
    required String baseUrl,
    required String text,
    String mode = 'free_talk',
    String jlptLevel = 'N5',
    String scenario = '',
    String sessionId = '',
  }) async {
    final body = <String, String>{
      'text': text,
      'mode': mode,
      'jlpt_level': jlptLevel,
    };
    if (scenario.isNotEmpty) body['scenario'] = scenario;
    if (sessionId.isNotEmpty) body['session_id'] = sessionId;

    late http.Response res;
    try {
      res = await _client
          .post(
            _uri(baseUrl, '/v1/conversation/turn'),
            headers: _headers(),
            body: body,
          )
          .timeout(ServerConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (_) {
      throw ApiException.network();
    }
    return ConversationResult.fromJson(await _decode(res));
  }

  /// Lấy danh sách phiên hội thoại.
  Future<List<SessionRecord>> getSessions({required String baseUrl}) async {
    late http.Response res;
    try {
      res = await _client
          .get(_uri(baseUrl, '/v1/sessions'))
          .timeout(ServerConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (_) {
      throw ApiException.network();
    }
    final list = await _decodeList(res);
    return list.map(SessionRecord.fromJson).toList();
  }

  /// Lấy các lượt hội thoại của một phiên.
  Future<List<TurnRecord>> getTurns({
    required String baseUrl,
    required String sessionId,
  }) async {
    late http.Response res;
    try {
      res = await _client
          .get(_uri(baseUrl, '/v1/sessions/$sessionId/turns'))
          .timeout(ServerConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (_) {
      throw ApiException.network();
    }
    final list = await _decodeList(res);
    return list.map(TurnRecord.fromJson).toList();
  }

  /// Lấy sổ từ vựng.
  Future<List<VocabularyRecord>> getVocabulary({required String baseUrl}) async {
    late http.Response res;
    try {
      res = await _client
          .get(_uri(baseUrl, '/v1/vocabulary'))
          .timeout(ServerConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (_) {
      throw ApiException.network();
    }
    final list = await _decodeList(res);
    return list.map(VocabularyRecord.fromJson).toList();
  }

  /// Gọi GET /health, trả về chuỗi tóm tắt trạng thái các engine.
  Future<String> health(String baseUrl) async {
    late http.Response res;
    try {
      res = await _client
          .get(_uri(baseUrl, '/health'))
          .timeout(ServerConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (_) {
      throw ApiException.network();
    }
    final data = await _decode(res);
    final gemini = data['gemini'] == true ? '✅' : '❌';
    final voicevox = data['voicevox'] == true ? '✅' : '❌';
    final rvc = data['rvc'] == true ? '✅' : '❌';
    return 'Backend ${data['status']} · chế độ ${data['mode']}\n'
        'Gemini $gemini · VOICEVOX $voicevox · RVC $rvc';
  }

  /// Xóa một phiên hội thoại.
  Future<bool> deleteSession({
    required String baseUrl,
    required String sessionId,
  }) async {
    late http.Response res;
    try {
      res = await _client
          .delete(_uri(baseUrl, '/v1/sessions/$sessionId'))
          .timeout(ServerConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.timeout();
    } catch (_) {
      throw ApiException.network();
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return true;
    throw ApiException.server(status: res.statusCode);
  }
}

/// Provider Riverpod cho ApiService.
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Provider trả về AppSettings hiện tại — đọc từ repository.
final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.load();
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}
