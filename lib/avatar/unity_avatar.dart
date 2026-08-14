import 'dart:async';
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
  Timer? _handshakeTimer;
  int _handshakeAttempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startHandshake());
  }

  @override
  void dispose() {
    _handshakeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ready = false;
      _startHandshake();
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
        _handshakeTimer?.cancel();
        if (_ready) return;
        _ready = true;
        _lastEmotion = null;
        _lastSpeechSeq = -1;
        debugPrint('[Avatar] Unity handshake=${message['type']}');
        _sync(ref.read(avatarControllerProvider));
      }
    } catch (_) {
      // Ignore unrelated/plain-text messages from Unity packages.
    }
  }

  /// Unity stays alive when its platform view is detached, so `READY` is only
  /// emitted on the very first launch. Ping until the bridge answers whenever
  /// this widget is created/resumed, then replay the latest avatar state.
  void _startHandshake() {
    if (!mounted) return;
    _handshakeTimer?.cancel();
    _handshakeAttempt = 0;
    resumeUnity();

    void ping() {
      if (!mounted || _ready) {
        _handshakeTimer?.cancel();
        return;
      }
      _handshakeAttempt += 1;
      debugPrint('[Avatar] Unity ping attempt=$_handshakeAttempt');
      sendToUnity(_bridgeObject, 'Ping', 'flutter_attach');
    }

    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || _ready) return;
      ping();
      _handshakeTimer = Timer.periodic(
        const Duration(milliseconds: 750),
        (_) => ping(),
      );
    });
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
        debugPrint('[Avatar] stop speech seq=${state.speechSeq}');
        sendToUnity(_bridgeObject, 'StopSpeech', '');
      } else {
        final cues = state.mouthCues
            .map((cue) => {'t_ms': cue.tMs, 'mouth': cue.mouth})
            .toList();
        debugPrint(
          '[Avatar] play speech seq=${state.speechSeq} '
          'cues=${cues.length} duration=${state.mouthCues.last.tMs}ms',
        );
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
  Widget build(BuildContext context) {
    final avatarState = ref.watch(avatarControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(avatarState);
    });
    return EmbedUnity(onMessageFromUnity: _onUnityMessage);
  }
}
