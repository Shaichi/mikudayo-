import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/vrm_avatar.dart';
import '../../data/services/api_service.dart';
import 'conversation_view_model.dart';
import 'widgets/chat_bubble.dart';

/// Màn hình hội thoại — text chat với Miku (Phase 1).
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(conversationViewModelProvider.notifier).sendText(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(conversationViewModelProvider);

    // Cuộn xuống khi có tin nhắn mới.
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hội thoại với Miku'),
        actions: [
          IconButton(
            tooltip: 'Làm mới phiên',
            onPressed: () {
              ref
                  .read(conversationViewModelProvider.notifier)
                  .addSystemMessage('🆕 Phiên mới — bắt đầu hội thoại lại.');
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Avatar 3D (VRM) + trạng thái.
          _Header(status: vm.statusLabel),
          const Divider(height: 1),
          // Danh sách tin nhắn.
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: vm.messages.length,
              itemBuilder: (context, i) {
                final msg = vm.messages[i];
                if (msg.kind == MessageKind.system) {
                  return _SystemMessage(text: msg.text);
                }
                return ChatBubble(
                  isUser: msg.isUser,
                  text: msg.displayText,
                  result: msg.result,
                );
              },
            ),
          ),
          // Ô nhập + nút gửi + push-to-talk.
          _InputBar(
            controller: _controller,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Avatar 3D thật (VRM qua WebView). Không cần emotion/mouthOpen —
          // VrmAvatar tự đọc avatarControllerProvider.
          const VrmAvatar(),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              color: status == 'Miku sẵn sàng!'
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.primary,
              fontWeight: status == 'Miku sẵn sàng!'
                  ? FontWeight.w400
                  : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends ConsumerWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  void _startRecording(WidgetRef ref) {
    ref.read(conversationViewModelProvider.notifier).startRecording();
  }

  void _stopRecording(WidgetRef ref) {
    ref.read(conversationViewModelProvider.notifier).stopRecordingAndSend();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final vm = ref.watch(conversationViewModelProvider);
    final scheme = Theme.of(context).colorScheme;
    final isBusy = vm.isBusy;
    final isRecording = vm.isRecording;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            // Nút push-to-talk (ghi mic — Phase 2).
            // Dùng Listener thay GestureDetector long-press: onPointerDown bắt đầu
            // ghi, onPointerUp/onPointerCancel dừng + gửi. Đảm bảo khi thả tay (kể cả
            // trượt ra ngoài nút) vẫn gửi được — không "cứ ghi âm tiếp".
            Listener(
              onPointerDown: isBusy
                  ? null
                  : (_) => _startRecording(ref),
              onPointerUp: isBusy
                  ? null
                  : (_) => _stopRecording(ref),
              onPointerCancel: isBusy
                  ? null
                  : (_) => _stopRecording(ref),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording
                      ? scheme.error
                      : scheme.primary,
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isBusy,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => isBusy ? null : onSend(),
                decoration: InputDecoration(
                  hintText: 'Nhập tiếng Nhật… (${settings.mode} / ${settings.jlptLevel})',
                  suffixIcon: isBusy
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: isBusy ? null : onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
                backgroundColor: scheme.primary,
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
