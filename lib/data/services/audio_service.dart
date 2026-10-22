import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Dịch vụ stream giọng trả lời của Miku trực tiếp từ backend.
class AudioService {
  AudioService() : _player = AudioPlayer();

  AudioPlayer? _player;

  /// Chuẩn bị stream URL; chưa phát để lip-sync có thể bắt đầu đúng thời điểm.
  Future<void> prepareUrl(String url) async {
    final player = _player ??= AudioPlayer();
    await player.setUrl(url);
  }

  Future<void> play() async {
    final player = _player ??= AudioPlayer();
    await player.play();
  }

  Future<void> stop() async {
    await _player?.stop();
  }

  /// Bật/tắt tiếng phát của Miku mà không làm gián đoạn playback hiện tại.
  Future<void> setMuted(bool muted) async {
    final player = _player ??= AudioPlayer();
    await player.setVolume(muted ? 0 : 1);
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}

final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
