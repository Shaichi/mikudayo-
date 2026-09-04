import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            colors: [Color(0xFFE8FAFB), MikuTheme.canvas, Color(0xFFFFF7FA)],
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
          color: MikuTheme.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'M',
            style: TextStyle(
              color: MikuTheme.stageCyan,
              fontSize: 20,
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
              'MIKU',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.2),
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
      color: MikuTheme.ink,
      borderRadius: BorderRadius.circular(MikuTheme.radiusLarge),
      boxShadow: [
        BoxShadow(
          color: MikuTheme.primary.withValues(alpha: 0.2),
          blurRadius: 30,
          offset: const Offset(0, 16),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        const Positioned(right: -38, top: -56, child: _HeroOrb(size: 180)),
        const Positioned(
          right: 34,
          bottom: -56,
          child: _HeroOrb(size: 130, color: MikuTheme.accent),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: MikuTheme.stageCyan,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LUYỆN NÓI CÙNG MIKU',
                      maxLines: 2,
                      style: TextStyle(
                        color: Color(0xFF9DC4C5),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Hôm nay mình\nnói chuyện gì?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 18),
              Material(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onChangeMode,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: MikuTheme.stageCyan,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            settings.practiceSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Semantics(
                button: true,
                label: 'Bắt đầu luyện nói với Miku',
                child: FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: MikuTheme.stageCyan,
                    foregroundColor: MikuTheme.ink,
                  ),
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Luyện ngay'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.size, this.color = MikuTheme.stageCyan});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.12)),
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
                color: MikuTheme.primary.withValues(alpha: 0.1),
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
      color: MikuTheme.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(MikuTheme.radiusMedium),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_outline_rounded, color: MikuTheme.primary),
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
