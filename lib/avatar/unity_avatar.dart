import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

import '../data/models/conversation_turn.dart';
import 'avatar_controller.dart';

/// Android/iOS Unity renderer. Flutter owns audio and sends only small JSON
/// emotion/mouth-cue messages to the stable Unity bridge object.
class UnityAvatar extends ConsumerStatefulWidget {
  const UnityAvatar({super.key});

  @override
  ConsumerState<UnityAvatar> createState() => _UnityAvatarState();
}

class _UnityAvatarState extends ConsumerState<UnityAvatar>
    with WidgetsBindingObserver {
  static const _bridgeObject = 'MikuAvatarBridge';
  bool _ready = false;
  MikuEmotion? _lastEmotion;
  int _lastSpeechSeq = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(avatarControllerProvider, (_, next) => _sync(next));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resumeUnity();
      sendToUnity(_bridgeObject, 'Ping', 'resume');
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      pauseUnity();
    }
  }

  void _onUnityMessage(String raw) {
    try {
      final message = jsonDecode(raw);
      if (message is Map &&
          (message['type'] == 'ready' || message['type'] == 'pong')) {
        _ready = true;
        _lastEmotion = null;
        _lastSpeechSeq = -1;
        _sync(ref.read(avatarControllerProvider));
      }
    } catch (_) {
      // Ignore unrelated/plain-text messages from Unity packages.
    }
  }

  void _sync(AvatarState state) {
    if (!_ready) return;
    if (state.emotion != _lastEmotion) {
      _lastEmotion = state.emotion;
      sendToUnity(
        _bridgeObject,
        'SetEmotion',
        jsonEncode({'emotion': state.emotion.name}),
      );
    }
    if (state.speechSeq != _lastSpeechSeq) {
      _lastSpeechSeq = state.speechSeq;
      if (state.mouthCues.isEmpty) {
        sendToUnity(_bridgeObject, 'StopSpeech', '');
      } else {
        final cues = state.mouthCues
            .map((cue) => {'t_ms': cue.tMs, 'mouth': cue.mouth})
            .toList();
        sendToUnity(
          _bridgeObject,
          'PlayMouthCues',
          jsonEncode({
            'seq': state.speechSeq,
            'duration_ms': state.mouthCues.last.tMs,
            'cues': cues,
          }),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      EmbedUnity(onMessageFromUnity: _onUnityMessage);
}
