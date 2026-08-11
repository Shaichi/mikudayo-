import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/avatar_controller.dart';
import '../../data/models/conversation_turn.dart';
import '../../data/services/api_service.dart';
import 'conversation_view_model.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/miku_avatar.dart';

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
    final avatar = ref.watch(avatarControllerProvider);

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
          // Avatar + trạng thái.
          _Header(emotion: avatar.emotion, isThinking: vm.isThinking),
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
          // Ô nhập + nút gửi.
          _InputBar(
            controller: _controller,
            isThinking: vm.isThinking,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.emotion, required this.isThinking});

  final MikuEmotion emotion;
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          MikuAvatar(emotion: emotion, radius: 42),
          const SizedBox(height: 8),
          Text(
            isThinking ? 'Miku đang suy nghĩ…' : 'Miku sẵn sàng!',
            style: TextStyle(
              color: isThinking
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isThinking ? FontWeight.w600 : FontWeight.w400,
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
    required this.isThinking,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isThinking;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isThinking,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => isThinking ? null : onSend(),
                decoration: InputDecoration(
                  hintText: 'Nhập tiếng Nhật… (${settings.mode} / ${settings.jlptLevel})',
                  suffixIcon: isThinking
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
              onPressed: isThinking ? null : onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
