import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/miku_decor.dart';
import '../../app/theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/api_service.dart';
import '../conversation/conversation_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../vocabulary/vocabulary_screen.dart';

/// Màn hình chính — đưa hành động luyện nói lên trước, các công cụ học tập ở
/// tầng thứ hai. Cấu hình hiện tại luôn được hiển thị trước khi bắt đầu.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MikuTheme.mint, MikuTheme.canvas, MikuTheme.blush],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                sliver: SliverList.list(
                  children: [
                    _HomeHeader(
                      onSettings: () => _push(context, const SettingsScreen()),
                    ),
                    const SizedBox(height: 22),
                    _PracticeHero(
                      settings: settings,
                      onStart: () => _push(context, const ConversationScreen()),
                      onChangeMode: () =>
                          _push(context, const SettingsScreen()),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Không gian học tập',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Xem lại những gì bạn đã nói và các từ mới Miku đã ghi nhớ.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FeatureGrid(
                      onHistory: () => _push(context, const HistoryScreen()),
                      onVocabulary: () =>
                          _push(context, const VocabularyScreen()),
                      onSettings: () => _push(context, const SettingsScreen()),
                    ),
                    const SizedBox(height: 24),
                    const _PracticeTip(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: MikuTheme.stageCyan,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'ミ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ミクと話そう',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: MikuTheme.ink,
              ),
            ),
            Text(
              'Bạn đồng hành tiếng Nhật',
              style: TextStyle(fontSize: 12, color: MikuTheme.mutedInk),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Mở cài đặt',
        onPressed: onSettings,
        icon: const Icon(Icons.tune_rounded),
      ),
    ],
  );
}

class _PracticeHero extends StatelessWidget {
  const _PracticeHero({
    required this.settings,
    required this.onStart,
    required this.onChangeMode,
  });

  final AppSettings settings;
  final VoidCallback onStart;
  final VoidCallback onChangeMode;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(MikuTheme.radiusLarge),
      border: Border.all(color: MikuTheme.stageCyan.withValues(alpha: 0.4)),
      boxShadow: [
        BoxShadow(
          color: MikuTheme.primary.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CandyStripe(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'きょうは なにを はなす？',
                style: TextStyle(
                  color: MikuTheme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hôm nay mình\nnói chuyện gì?',
                style: TextStyle(
                  color: MikuTheme.ink,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: MikuTheme.mint,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onChangeMode,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 17,
                          color: MikuTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            settings.practiceSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MikuTheme.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Text(
                          'Đổi',
                          style: TextStyle(
                            color: MikuTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                button: true,
                label: 'Bắt đầu luyện nói với Miku',
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('Nói chuyện với Miku'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.onHistory,
    required this.onVocabulary,
    required this.onSettings,
  });

  final VoidCallback onHistory;
  final VoidCallback onVocabulary;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: itemWidth,
            child: _FeatureCard(
              icon: Icons.history_rounded,
              title: 'Lịch sử',
              subtitle: 'Xem lại các buổi luyện',
              onTap: onHistory,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _FeatureCard(
              icon: Icons.menu_book_rounded,
              title: 'Từ vựng',
              subtitle: 'Ôn những từ đã gặp',
              onTap: onVocabulary,
            ),
          ),
          SizedBox(
            width: constraints.maxWidth,
            child: _FeatureCard(
              icon: Icons.tune_rounded,
              title: 'Thiết lập buổi học',
              subtitle: 'Chế độ, trình độ và bối cảnh luyện tập',
              onTap: onSettings,
              horizontal: true,
            ),
          ),
        ],
      );
    },
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MikuTheme.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MikuTheme.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: MikuTheme.primary),
            ),
            SizedBox(width: horizontal ? 14 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (horizontal) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _PracticeTip extends StatelessWidget {
  const _PracticeTip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MikuTheme.blush,
      borderRadius: BorderRadius.circular(MikuTheme.radiusMedium),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.music_note_rounded, color: MikuTheme.accent),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Mẹo nhỏ: nói từng câu ngắn và rõ. Bạn có thể xem câu sửa ngay sau mỗi lượt.',
          ),
        ),
      ],
    ),
  );
}
