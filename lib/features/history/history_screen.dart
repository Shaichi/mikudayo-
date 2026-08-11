import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/session_record.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/services/api_service.dart';

/// Màn hình lịch sử: danh sách phiên → chi tiết các lượt hội thoại.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<SessionRecord>? _sessions;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final serverUrl = ref.read(appSettingsProvider).serverUrl;
    try {
      final sessions =
          await ref.read(conversationRepositoryProvider).getSessions(serverUrl);
      setState(() => _sessions = sessions);
    } on ApiException catch (e) {
      setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử hội thoại'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _load);
    }
    final sessions = _sessions ?? const [];
    if (sessions.isEmpty) {
      return const Center(
        child: Text('Chưa có hội thoại nào.\nBắt đầu trò chuyện với Miku nhé!',
            textAlign: TextAlign.center),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _SessionCard(
        session: sessions[i],
        onTap: () => _openSession(sessions[i]),
        onDelete: () => _deleteSession(sessions[i]),
      ),
    );
  }

  Future<void> _openSession(SessionRecord session) async {
    final serverUrl = ref.read(appSettingsProvider).serverUrl;
    try {
      final turns = await ref
          .read(conversationRepositoryProvider)
          .getTurns(serverUrl, session.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _SessionDetailScreen(session: session, turns: turns),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  Future<void> _deleteSession(SessionRecord session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa phiên?'),
        content: Text('Xóa phiên ${session.modeLabel} này và toàn bộ lượt hội thoại?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final serverUrl = ref.read(appSettingsProvider).serverUrl;
    try {
      await ref
          .read(conversationRepositoryProvider)
          .deleteSession(serverUrl, session.id);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  final SessionRecord session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.chat_bubble_outline, color: scheme.primary),
        ),
        title: Text('${session.modeLabel} · ${session.jlptLevel}'),
        subtitle: Text(
          '${session.turnCount} lượt · ${_formatDate(session.createdAt)}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: IconButton(
          tooltip: 'Xóa phiên',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final t = iso.split('T');
    return t.length == 2 ? '${t[0]} ${t[1].substring(0, 5)}' : iso;
  }
}

class _SessionDetailScreen extends StatelessWidget {
  const _SessionDetailScreen({required this.session, required this.turns});

  final SessionRecord session;
  final List<TurnRecord> turns;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${session.modeLabel} — chi tiết')),
      body: turns.isEmpty
          ? const Center(child: Text('Phiên chưa có lượt nào.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: turns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = turns[i];
                final isUserEmpty = (t.transcriptJa ?? '').isEmpty;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUserEmpty) ...[
                          _Labeled(text: 'Bạn', body: t.transcriptJa!),
                          const SizedBox(height: 8),
                        ],
                        _Labeled(text: 'Miku (${t.emotion})', body: t.replyJa),
                        if (t.correctionJa != null &&
                            t.correctionJa!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _Labeled(
                            text: '✨ Câu sửa',
                            body: t.correctionJa!,
                            accent: true,
                          ),
                        ],
                        if (t.explanationVi != null &&
                            t.explanationVi!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            t.explanationVi!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.text,
    required this.body,
    this.accent = false,
  });

  final String text;
  final String body;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: accent ? scheme.error : scheme.primary,
          ),
        ),
        Text(body, style: const TextStyle(fontSize: 15, height: 1.4)),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
