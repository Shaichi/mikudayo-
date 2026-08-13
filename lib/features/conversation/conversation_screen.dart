import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/vrm_avatar.dart';
import '../../avatar/unity_avatar.dart';
import '../../data/services/api_service.dart';
import '../../data/services/audio_service.dart';
import 'conversation_view_model.dart';
import 'widgets/chat_bubble.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();
  final _textFocus = FocusNode();
  bool _showComposer = false;
  bool _soundEnabled = true;

  static const _background = Color(0xFF03080D);

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _textFocus.unfocus();
    setState(() => _showComposer = false);
    ref.read(conversationViewModelProvider.notifier).sendText(text);
  }

  void _openComposer() {
    setState(() => _showComposer = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _textFocus.requestFocus(),
    );
  }

  void _showHistory(ConversationState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(messages: state.messages),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationViewModelProvider);
    final settings = ref.watch(appSettingsProvider);
    final latestMiku = state.activeReply.isNotEmpty
        ? state.activeReply
        : state.messages.where((m) => m.isMiku).lastOrNull?.text ??
              'こんにちは。今日は何を話そうか？';

    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AmbientBackground(),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mobile =
                      defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS;
                  return mobile
                      ? const UnityAvatar()
                      : VrmAvatar(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        );
                },
              ),
            ),
          ),
          const Positioned.fill(child: _StageGradient()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: Column(
                children: [
                  _TopBar(
                    phase: state.phase,
                    onClose: () => Navigator.maybePop(context),
                    onHistory: () => _showHistory(state),
                    onRefresh: () => ref
                        .read(conversationViewModelProvider.notifier)
                        .addSystemMessage('Phiên trò chuyện mới'),
                  ),
                  const Spacer(),
                  _StatusPill(
                    phase: state.phase,
                    recordingSeconds: state.recordingSeconds,
                  ),
                  const SizedBox(height: 12),
                  _SubtitleCard(text: latestMiku, phase: state.phase),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _showComposer
                        ? _Composer(
                            key: const ValueKey('composer'),
                            controller: _textController,
                            focusNode: _textFocus,
                            enabled: !state.isBusy,
                            hint: '${settings.mode} · ${settings.jlptLevel}',
                            onSend: _sendText,
                            onClose: () {
                              _textFocus.unfocus();
                              setState(() => _showComposer = false);
                            },
                          )
                        : _ControlDock(
                            key: const ValueKey('controls'),
                            state: state,
                            soundEnabled: _soundEnabled,
                            onKeyboard: _openComposer,
                            onSound: () {
                              final enabled = !_soundEnabled;
                              setState(() => _soundEnabled = enabled);
                              ref.read(audioServiceProvider).setMuted(!enabled);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -0.15),
        radius: 0.9,
        colors: [Color(0xFF0C353A), Color(0xFF061218), Color(0xFF02060A)],
        stops: [0, 0.5, 1],
      ),
    ),
  );
}

class _StageGradient extends StatelessWidget {
  const _StageGradient();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.46),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.86),
          ],
          stops: const [0, 0.22, 0.58, 1],
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.phase,
    required this.onClose,
    required this.onHistory,
    required this.onRefresh,
  });

  final ConversationPhase phase;
  final VoidCallback onClose;
  final VoidCallback onHistory;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _GlassButton(icon: Icons.close_rounded, onTap: onClose),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MIKU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'YOUR JAPANESE COMPANION',
              style: TextStyle(
                color: Color(0xFF87A9AD),
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      _GlassButton(icon: Icons.refresh_rounded, onTap: onRefresh),
      const SizedBox(width: 8),
      _GlassButton(icon: Icons.chat_bubble_outline_rounded, onTap: onHistory),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.phase, required this.recordingSeconds});
  final ConversationPhase phase;
  final int recordingSeconds;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      ConversationPhase.recording => (
        'ĐANG NGHE · ${recordingSeconds}s',
        const Color(0xFFFF668A),
      ),
      ConversationPhase.uploading => ('ĐANG GỬI', const Color(0xFFFFD166)),
      ConversationPhase.thinking => ('ĐANG SUY NGHĨ', const Color(0xFF52F4DE)),
      ConversationPhase.synthesizing => (
        'ĐANG CHUẨN BỊ GIỌNG NÓI',
        const Color(0xFF52F4DE),
      ),
      ConversationPhase.playing => ('MIKU ĐANG NÓI', const Color(0xFF52F4DE)),
      ConversationPhase.error => ('CÓ LỖI', const Color(0xFFFF668A)),
      ConversationPhase.idle => ('SẴN SÀNG', const Color(0xFF82CFC5)),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color, blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitleCard extends StatelessWidget {
  const _SubtitleCard({required this.text, required this.phase});
  final String text;
  final ConversationPhase phase;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 560),
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: text.isEmpty ? 0 : 1,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          height: 1.45,
          fontWeight: FontWeight.w500,
          shadows: [Shadow(color: Colors.black, blurRadius: 12)],
        ),
      ),
    ),
  );
}

class _ControlDock extends ConsumerWidget {
  const _ControlDock({
    super.key,
    required this.state,
    required this.soundEnabled,
    required this.onKeyboard,
    required this.onSound,
  });
  final ConversationState state;
  final bool soundEnabled;
  final VoidCallback onKeyboard;
  final VoidCallback onSound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(conversationViewModelProvider.notifier);
    final recording = state.isRecording;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GlassButton(
          icon: Icons.keyboard_rounded,
          onTap: state.isBusy ? null : onKeyboard,
          size: 52,
        ),
        const SizedBox(width: 20),
        Listener(
          onPointerDown: state.isBusy ? null : (_) => notifier.startRecording(),
          onPointerUp: state.isBusy
              ? null
              : (_) => notifier.stopRecordingAndSend(),
          onPointerCancel: state.isBusy
              ? null
              : (_) => notifier.cancelRecording(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recording
                  ? const Color(0xFFFF557A)
                  : const Color(0xFF52F4DE),
              boxShadow: [
                BoxShadow(
                  color:
                      (recording
                              ? const Color(0xFFFF557A)
                              : const Color(0xFF52F4DE))
                          .withValues(alpha: 0.32),
                  blurRadius: recording ? 28 : 18,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              recording ? Icons.stop_rounded : Icons.mic_rounded,
              color: const Color(0xFF03201D),
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: 20),
        _GlassButton(
          icon: soundEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          onTap: onSound,
          size: 52,
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hint,
    required this.onSend,
    required this.onClose,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: const Color(0xFF102126).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Color(0xFF8FA8AA)),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration.collapsed(
                  hintText: 'Nhập tiếng Nhật…  $hint',
                  hintStyle: const TextStyle(color: Color(0xFF769093)),
                ),
              ),
            ),
            IconButton(
              onPressed: enabled ? onSend : null,
              icon: const Icon(
                Icons.arrow_upward_rounded,
                color: Color(0xFF52F4DE),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap, this.size = 44});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.08),
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          color: onTap == null ? Colors.white24 : Colors.white,
          size: size * 0.47,
        ),
      ),
    ),
  );
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.messages});
  final List<Message> messages;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.62,
    minChildSize: 0.35,
    maxChildSize: 0.9,
    builder: (context, controller) => DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF091318),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'Lịch sử trò chuyện',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có cuộc trò chuyện',
                      style: TextStyle(color: Color(0xFF82999B)),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final message = messages[i];
                      if (message.kind == MessageKind.system) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            message.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF82999B),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return ChatBubble(
                        isUser: message.isUser,
                        text: message.displayText,
                        result: message.result,
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
