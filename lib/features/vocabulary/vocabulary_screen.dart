import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/vocabulary_record.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/services/api_service.dart';

/// Màn hình sổ từ vựng — danh sách từ đã học từ các lượt hội thoại.
class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  List<VocabularyRecord>? _items;
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
      final items =
          await ref.read(conversationRepositoryProvider).getVocabulary(serverUrl);
      setState(() => _items = items);
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
        title: const Text('Sổ từ vựng'),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final items = _items ?? const [];
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có từ vựng nào.\nTrò chuyện để Miku bổ sung từ mới vào sổ nhé!',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _VocabTile(item: items[i]),
    );
  }
}

class _VocabTile extends StatelessWidget {
  const _VocabTile({required this.item});

  final VocabularyRecord item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            item.word.isEmpty ? '語' : item.word.characters.first.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
          ),
        ),
        title: Text(item.word,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((item.reading ?? '').isNotEmpty)
              Text(
                item.reading ?? '',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if ((item.meaningVi ?? '').isNotEmpty)
              Text(item.meaningVi!, style: const TextStyle(fontSize: 13)),
          ],
        ),
        trailing: Text(
          '${item.reviewCount} lượt',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
