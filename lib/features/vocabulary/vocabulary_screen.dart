import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/vocabulary_record.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/services/api_service.dart';
import '../conversation/conversation_screen.dart';

enum _VocabSort { recent, frequent, alphabetical }

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
  final _searchController = TextEditingController();
  String _query = '';
  _VocabSort _sort = _VocabSort.recent;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      final items = await ref
          .read(conversationRepositoryProvider)
          .getVocabulary(serverUrl);
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
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
      body: SafeArea(top: false, child: _buildBody()),
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
              Icon(
                Icons.cloud_off,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
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
      return _EmptyVocabulary(
        onStart: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ConversationScreen())),
      );
    }
    final visibleItems = _visibleItems(items);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Tìm từ, cách đọc hoặc nghĩa…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${visibleItems.length} từ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<_VocabSort>(
                    tooltip: 'Sắp xếp từ vựng',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _VocabSort.recent,
                        child: Text('Mới gặp gần đây'),
                      ),
                      PopupMenuItem(
                        value: _VocabSort.frequent,
                        child: Text('Gặp nhiều nhất'),
                      ),
                      PopupMenuItem(
                        value: _VocabSort.alphabetical,
                        child: Text('Theo bảng chữ cái'),
                      ),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.sort_rounded, size: 18),
                      label: Text(_sortLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: visibleItems.isEmpty
              ? const Center(child: Text('Không tìm thấy từ phù hợp.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _VocabTile(
                    item: visibleItems[i],
                    onTap: () => _showDetail(visibleItems[i]),
                  ),
                ),
        ),
      ],
    );
  }

  String get _sortLabel => switch (_sort) {
    _VocabSort.recent => 'Gần đây',
    _VocabSort.frequent => 'Gặp nhiều',
    _VocabSort.alphabetical => 'A–Z',
  };

  List<VocabularyRecord> _visibleItems(List<VocabularyRecord> source) {
    final normalized = _query.toLowerCase();
    final result = source.where((item) {
      if (normalized.isEmpty) return true;
      return item.word.toLowerCase().contains(normalized) ||
          (item.reading ?? '').toLowerCase().contains(normalized) ||
          (item.meaningVi ?? '').toLowerCase().contains(normalized);
    }).toList();
    result.sort(switch (_sort) {
      _VocabSort.recent => (a, b) => b.firstSeenAt.compareTo(a.firstSeenAt),
      _VocabSort.frequent => (a, b) => b.reviewCount.compareTo(a.reviewCount),
      _VocabSort.alphabetical => (a, b) => a.word.compareTo(b.word),
    });
    return result;
  }

  void _showDetail(VocabularyRecord item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.word, style: Theme.of(context).textTheme.headlineMedium),
            if ((item.reading ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.reading!,
                style: const TextStyle(color: MikuTheme.primary, fontSize: 16),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Nghĩa tiếng Việt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              (item.meaningVi ?? '').isEmpty
                  ? 'Chưa có nghĩa.'
                  : item.meaningVi!,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  Icons.repeat_rounded,
                  size: 18,
                  color: MikuTheme.mutedInk,
                ),
                const SizedBox(width: 8),
                Text('Đã gặp ${item.reviewCount} lần trong hội thoại'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabTile extends StatelessWidget {
  const _VocabTile({required this.item, required this.onTap});

  final VocabularyRecord item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            item.word.isEmpty ? '語' : item.word.characters.first.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        title: Text(
          item.word,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
          '×${item.reviewCount}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _EmptyVocabulary extends StatelessWidget {
  const _EmptyVocabulary({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: MikuTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: MikuTheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sổ từ vựng đang trống',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Trò chuyện với Miku để tự động lưu những từ mới hữu ích.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Luyện ngay'),
          ),
        ],
      ),
    ),
  );
}
