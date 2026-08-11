import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Dịch vụ âm thanh: ghi mic (Phase 2) + phát audio (Phase 3).
///
/// - Ghi: `record` package, WAV 16kHz mono (phù hợp Gemini audio understanding).
/// - Phát: `just_audio` phát audio_url hoặc bytes.
class AudioService {
  AudioService() : _recorder = AudioRecorder() {
    _player = AudioPlayer();
  }

  final AudioRecorder _recorder;
  AudioPlayer? _player;

  bool _permissionGranted = false;

  /// Yêu cầu quyền mic. Trả true nếu OK.
  Future<bool> ensurePermission() async {
    try {
      _permissionGranted = await _recorder.hasPermission();
      return _permissionGranted;
    } catch (_) {
      return false;
    }
  }

  /// Quyền mic đã được cấp chưa.
  bool get hasPermission => _permissionGranted;

  /// Bắt đầu ghi vào file tạm. Trả path file đang ghi.
  Future<String> startRecording() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/miku_input.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    return path;
  }

  /// Dừng ghi, trả bytes WAV.
  Future<List<int>> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return const [];
    final file = File(path);
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();
    return bytes;
  }

  /// Phát audio từ URL (server). Trả về AudioPlayer để chờ kết thúc.
  Future<void> playUrl(String url) async {
    final player = _player ??= AudioPlayer();
    await player.setUrl(url);
    await player.play();
  }

  /// Tải bytes audio từ URL (audio_url tương đối trên server).
  Future<List<int>> fetchAudio(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Không tải được audio (${res.statusCode})');
    }
    return res.bodyBytes;
  }

  /// Phát từ bytes WAV.
  Future<void> playBytes(List<int> bytes) async {
    final player = _player ??= AudioPlayer();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/miku_reply.wav';
    final file = File(path);
    await file.writeAsBytes(bytes);
    await player.setFilePath(path);
    await player.play();
  }

  Future<void> stop() async {
    await _player?.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await _player?.dispose();
    _player = null;
  }

  /// Hủy ghi đang dở (nếu người dùng bỏ giữa chừng).
  Future<void> cancelRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }
  }
}

final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
