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
  bool _slowStart = false;
  MikuEmotion? _lastEmotion;
  int _lastSpeechSeq = -1;
  int _lastGestureSeq = -1;
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
      if (mounted) {
        setState(() {
          _ready = false;
          _slowStart = false;
        });
      }
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
        if (mounted) {
          setState(() {
            _ready = true;
            _slowStart = false;
          });
        } else {
          _ready = true;
        }
        _lastEmotion = null;
        _lastSpeechSeq = -1;
        _lastGestureSeq = -1;
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
      if (_handshakeAttempt == 10 && mounted) {
        setState(() => _slowStart = true);
      }
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

  void _retryHandshake() {
    setState(() {
      _ready = false;
      _slowStart = false;
    });
    _startHandshake();
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
    if (state.gestureSeq != _lastGestureSeq) {
      _lastGestureSeq = state.gestureSeq;
      if (state.gesture == MikuGesture.none) {
        sendToUnity(_bridgeObject, 'StopGesture', '');
      } else {
        sendToUnity(
          _bridgeObject,
          'PlayGesture',
          jsonEncode({'gesture': state.gesture.name}),
        );
      }
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
    return Stack(
      fit: StackFit.expand,
      children: [
        EmbedUnity(onMessageFromUnity: _onUnityMessage),
        if (!_ready)
          ColoredBox(
            color: const Color(0xFF03080D).withValues(alpha: 0.72),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF102126).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF52F4DE),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _slowStart
                          ? 'Avatar đang khởi động lâu hơn dự kiến.'
                          : 'Đang chuẩn bị Miku…',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (_slowStart) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _retryHandshake,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
