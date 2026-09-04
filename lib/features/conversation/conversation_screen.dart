import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/vrm_avatar.dart';
import '../../avatar/unity_avatar.dart';
import '../../app/theme.dart';
import '../../data/models/conversation_turn.dart';
import '../../data/services/api_service.dart';
import '../../data/services/audio_service.dart';
import '../settings/settings_screen.dart';
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

  Future<void> _startNewSession(ConversationState state) async {
    if (state.isBusy) return;
    final hasConversation = state.messages.any(
      (message) => message.kind != MessageKind.system,
    );
    if (hasConversation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.add_comment_outlined),
          title: const Text('Bắt đầu phiên mới?'),
          content: const Text(
            'Phiên hiện tại vẫn được lưu trong Lịch sử. Miku sẽ bắt đầu lại với ngữ cảnh mới.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Phiên mới'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await ref.read(conversationViewModelProvider.notifier).startNewSession();
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationViewModelProvider);
    final settings = ref.watch(appSettingsProvider);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final latestMiku = state.activeReply.isNotEmpty
        ? state.activeReply
        : state.messages.where((m) => m.isMiku).lastOrNull?.text ??
              'こんにちは。今日は何を話そうか？';
    final latestUser = state.messages.where((m) => m.isUser).lastOrNull?.text;
    final latestResult = state.messages
        .where((m) => m.isMiku && m.result != null)
        .lastOrNull
        ?.result;

    return Scaffold(
      backgroundColor: _background,
      // Giữ nguyên viewport Flutter/Unity khi bàn phím mở. Chỉ composer được
      // dịch lên bằng transform ở dưới, nên camera 3D không đổi tỷ lệ.
      resizeToAvoidBottomInset: false,
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
                    practiceLabel: settings.practiceSummary,
                    onClose: () => Navigator.maybePop(context),
                    onHistory: () => _showHistory(state),
                    onRefresh: state.isBusy
                        ? null
                        : () => _startNewSession(state),
                  ),
                  const Spacer(),
                  if (state.phase == ConversationPhase.thinking &&
                      latestUser != null) ...[
                    _UserEcho(text: latestUser),
                    const SizedBox(height: 10),
                  ],
                  _StatusPill(
                    phase: state.phase,
                    recordingSeconds: state.recordingSeconds,
                  ),
                  const SizedBox(height: 12),
                  if (state.phase == ConversationPhase.error)
                    _ConversationError(
                      message:
                          state.errorMessage ?? 'Đã có lỗi. Vui lòng thử lại.',
                      onDismiss: () => ref
                          .read(conversationViewModelProvider.notifier)
                          .clearError(),
                      onKeyboard: () {
                        ref
                            .read(conversationViewModelProvider.notifier)
                            .clearError();
                        _openComposer();
                      },
                      onSettings: _openSettings,
                    )
                  else
                    _SubtitleCard(text: latestMiku),
                  if (state.phase == ConversationPhase.idle &&
                      latestResult != null &&
                      (latestResult.correctionJa?.isNotEmpty == true ||
                          latestResult.explanationVi?.isNotEmpty == true ||
                          latestResult.vocabulary.isNotEmpty)) ...[
                    const SizedBox(height: 10),
                    _LearningPeek(
                      result: latestResult,
                      onTap: () => _showHistory(state),
                    ),
                  ],
                  const SizedBox(height: 18),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(
                      0,
                      _showComposer ? -keyboardInset : 0,
                      0,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _showComposer
                          ? _Composer(
                              key: const ValueKey('composer'),
                              controller: _textController,
                              focusNode: _textFocus,
                              enabled: !state.isBusy,
                              hint: settings.practiceSummary,
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
                                ref
                                    .read(audioServiceProvider)
                                    .setMuted(!enabled);
                              },
                            ),
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
    required this.practiceLabel,
    required this.onClose,
    required this.onHistory,
    required this.onRefresh,
  });

  final String practiceLabel;
  final VoidCallback onClose;
  final VoidCallback onHistory;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _GlassButton(
        icon: Icons.close_rounded,
        tooltip: 'Đóng buổi luyện',
        onTap: onClose,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MIKU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              practiceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9BB9BB),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
      _GlassButton(
        icon: Icons.add_comment_outlined,
        tooltip: onRefresh == null
            ? 'Đang xử lý lượt hiện tại'
            : 'Bắt đầu phiên mới',
        onTap: onRefresh,
      ),
      const SizedBox(width: 8),
      _GlassButton(
        icon: Icons.chat_bubble_outline_rounded,
        tooltip: 'Xem nội dung trò chuyện',
        onTap: onHistory,
      ),
    ],
  );
}

class _UserEcho extends StatelessWidget {
  const _UserEcho({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_rounded, size: 16, color: Color(0xFF9BB9BB)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
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
      ConversationPhase.recognizing => (
        'ĐANG NHẬN DẠNG',
        const Color(0xFFFFD166),
      ),
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

class _SubtitleCard extends StatefulWidget {
  const _SubtitleCard({required this.text});

  final String text;

  @override
  State<_SubtitleCard> createState() => _SubtitleCardState();
}

class _SubtitleCardState extends State<_SubtitleCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _SubtitleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: _expanded
        ? 'Thu gọn câu trả lời của Miku'
        : 'Mở rộng câu trả lời của Miku',
    child: GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.text.isEmpty ? 0 : 1,
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                height: 1.45,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black, blurRadius: 12)],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConversationError extends StatelessWidget {
  const _ConversationError({
    required this.message,
    required this.onDismiss,
    required this.onKeyboard,
    required this.onSettings,
  });

  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onKeyboard;
  final VoidCallback onSettings;

  bool get _isConnectionError {
    final normalized = message.toLowerCase();
    return normalized.contains('kết nối') ||
        normalized.contains('máy chủ') ||
        normalized.contains('network');
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 560),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF35151E).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF668A).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFF8DA6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng thông báo',
                    onPressed: onDismiss,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isConnectionError)
                    TextButton(
                      onPressed: onSettings,
                      child: const Text('Cài đặt máy chủ'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onKeyboard,
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text('Nhập lại'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LearningPeek extends StatelessWidget {
  const _LearningPeek({required this.result, required this.onTap});

  final ConversationResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (result.correctionJa?.isNotEmpty == true ||
        result.explanationVi?.isNotEmpty == true) {
      parts.add('Có nhận xét');
    }
    if (result.vocabulary.isNotEmpty) {
      parts.add('${result.vocabulary.length} từ mới');
    }
    return Material(
      color: Colors.black.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.school_outlined,
                color: MikuTheme.stageCyan,
                size: 17,
              ),
              const SizedBox(width: 8),
              Text(
                parts.join(' · '),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          tooltip: state.isBusy
              ? 'Đang xử lý lượt hiện tại'
              : 'Nhập bằng bàn phím',
          onTap: state.isBusy ? null : onKeyboard,
          size: 52,
        ),
        const SizedBox(width: 20),
        Semantics(
          button: true,
          enabled: !state.isBusy,
          label: recording
              ? 'Dừng nghe và gửi câu nói'
              : 'Bắt đầu nói tiếng Nhật',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: state.isBusy
                ? null
                : () {
                    if (recording) {
                      notifier.stopVoiceRecognitionAndSend();
                    } else {
                      notifier.startVoiceRecognition();
                    }
                  },
            onLongPressStart: state.isBusy || recording
                ? null
                : (_) => notifier.startVoiceRecognition(),
            onLongPressEnd: state.isBusy
                ? null
                : (_) => notifier.stopVoiceRecognitionAndSend(),
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
        ),
        const SizedBox(width: 20),
        _GlassButton(
          icon: soundEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          tooltip: soundEnabled ? 'Tắt tiếng Miku' : 'Bật tiếng Miku',
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
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: Material(
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
