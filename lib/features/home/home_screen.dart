import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../conversation/conversation_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../vocabulary/vocabulary_screen.dart';

/// Màn hình chính — cổng điều hướng tới các tính năng.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F7FA), Color(0xFFF4FAFC)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
            children: [
              const SizedBox(height: 40),
              // Avatar Miku lớn.
              const _HeroAvatar(),
              const SizedBox(height: 16),
              const Text(
                'Miku Japanese Conversation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: MikuTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Luyện nói tiếng Nhật cùng Miku',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              // Các nút tính năng.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _FeatureButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'Bắt đầu hội thoại',
                      subtitle: 'Text chat với Miku (Phase 1)',
                      onTap: () => _push(context, const ConversationScreen()),
                    ),
                    const SizedBox(height: 12),
                    _FeatureButton(
                      icon: Icons.history,
                      label: 'Lịch sử hội thoại',
                      subtitle: 'Xem lại các phiên đã trò chuyện',
                      onTap: () => _push(context, const HistoryScreen()),
                    ),
                    const SizedBox(height: 12),
                    _FeatureButton(
                      icon: Icons.menu_book_outlined,
                      label: 'Sổ từ vựng',
                      subtitle: 'Từ mới đã học',
                      onTap: () => _push(context, const VocabularyScreen()),
                    ),
                    const SizedBox(height: 12),
                    _FeatureButton(
                      icon: Icons.settings_outlined,
                      label: 'Cài đặt',
                      subtitle: 'Server, chế độ học, cấp độ JLPT',
                      onTap: () => _push(context, const SettingsScreen()),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Phase 1 · Text chat',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
            ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MikuTheme.secondary, MikuTheme.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: MikuTheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Text('🎤', style: TextStyle(fontSize: 52)),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
