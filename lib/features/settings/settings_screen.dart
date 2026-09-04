import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/api_service.dart';

const _modes = ['free_talk', 'correction', 'roleplay'];
const _levels = ['N5', 'N4', 'N3'];
const _scenarios = ['', 'コンビニ', 'レストラン', '学校', '駅', '面接', '旅行', '買い物'];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _serverCtrl;
  String _mode = 'free_talk';
  String _level = 'N5';
  String _scenario = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _serverCtrl = TextEditingController(text: settings.serverUrl);
    _mode = settings.mode;
    _level = settings.jlptLevel;
    _scenario = settings.scenario;
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    super.dispose();
  }

  String get _normalizedUrl {
    final value = _serverCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    return value.isEmpty ? 'https://mikudayo.onrender.com' : value;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.update(
      AppSettings(
        serverUrl: _normalizedUrl,
        mode: _mode,
        jlptLevel: _level,
        scenario: _mode == 'roleplay' ? _scenario : '',
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã lưu thiết lập buổi học')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập buổi học')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Chọn cách Miku trò chuyện và độ khó phù hợp với mục tiêu hôm nay.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _SettingsCard(
              title: 'Bạn muốn luyện gì?',
              icon: Icons.forum_outlined,
              child: Column(
                children: [
                  for (final mode in _modes) ...[
                    _ModeOption(
                      mode: mode,
                      selected: _mode == mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                    if (mode != _modes.last) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SettingsCard(
              title: 'Trình độ JLPT',
              icon: Icons.school_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        for (final level in _levels)
                          ButtonSegment(value: level, label: Text(level)),
                      ],
                      selected: {_level},
                      onSelectionChanged: (value) {
                        setState(() => _level = value.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _levelDescription(_level),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _mode != 'roleplay'
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const ValueKey('scenario'),
                      padding: const EdgeInsets.only(top: 14),
                      child: _SettingsCard(
                        title: 'Bối cảnh đóng vai',
                        icon: Icons.location_on_outlined,
                        child: DropdownButtonFormField<String>(
                          initialValue: _scenario,
                          decoration: const InputDecoration(
                            labelText: 'Chọn tình huống',
                          ),
                          items: [
                            for (final scenario in _scenarios)
                              DropdownMenuItem(
                                value: scenario,
                                child: Text(
                                  scenario.isEmpty
                                      ? 'Miku tự chọn bối cảnh'
                                      : _scenarioLabel(scenario),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _scenario = value ?? '');
                          },
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Đang lưu…' : 'Lưu thiết lập'),
            ),
            const SizedBox(height: 20),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.developer_mode_outlined),
                title: const Text('Kết nối máy chủ'),
                subtitle: const Text('Tùy chọn nâng cao'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  TextField(
                    controller: _serverCtrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ backend',
                      hintText: 'https://mikudayo.onrender.com',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chỉ thay đổi mục này khi dùng máy chủ riêng. Điện thoại thật không thể dùng 127.0.0.1 của máy tính.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HealthCheckCard(serverUrl: _normalizedUrl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _levelDescription(String level) => switch (level) {
    'N5' => 'Câu ngắn, từ vựng cơ bản và tốc độ dễ theo dõi.',
    'N4' => 'Hội thoại đời thường với cấu trúc đa dạng hơn.',
    'N3' => 'Chủ đề rộng hơn và cách diễn đạt tự nhiên hơn.',
    _ => '',
  };
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MikuTheme.primary, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final String mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (mode) {
      'correction' => (
        Icons.auto_fix_high_rounded,
        'Luyện sửa lỗi',
        'Miku góp ý và giải thích câu của bạn',
      ),
      'roleplay' => (
        Icons.theater_comedy_outlined,
        'Đóng vai tình huống',
        'Thực hành hội thoại trong bối cảnh cụ thể',
      ),
      _ => (
        Icons.chat_bubble_outline_rounded,
        'Trò chuyện tự do',
        'Nói về bất kỳ chủ đề nào bạn thích',
      ),
    };
    return Material(
      color: selected
          ? MikuTheme.primary.withValues(alpha: 0.1)
          : MikuTheme.canvas,
      borderRadius: BorderRadius.circular(MikuTheme.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MikuTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? MikuTheme.primary : MikuTheme.mutedInk,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MikuTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? MikuTheme.primary : MikuTheme.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthCheckCard extends ConsumerStatefulWidget {
  const _HealthCheckCard({required this.serverUrl});

  final String serverUrl;

  @override
  ConsumerState<_HealthCheckCard> createState() => _HealthCheckCardState();
}

class _HealthCheckCardState extends ConsumerState<_HealthCheckCard> {
  bool _checking = false;
  String _result = 'Chưa kiểm tra kết nối';
  bool? _healthy;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _healthy = null;
      _result = 'Đang kiểm tra…';
    });
    try {
      final result = await ref
          .read(apiServiceProvider)
          .health(widget.serverUrl);
      if (!mounted) return;
      setState(() {
        _healthy = true;
        _result = result;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _healthy = false;
        _result = 'Không kết nối được với máy chủ này.';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MikuTheme.canvas,
      borderRadius: BorderRadius.circular(MikuTheme.radiusSmall),
    ),
    child: Row(
      children: [
        Icon(
          _healthy == true
              ? Icons.check_circle_rounded
              : _healthy == false
              ? Icons.error_outline_rounded
              : Icons.monitor_heart_outlined,
          color: _healthy == true
              ? Colors.green
              : _healthy == false
              ? Theme.of(context).colorScheme.error
              : MikuTheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(_result, style: const TextStyle(fontSize: 12.5))),
        const SizedBox(width: 8),
        if (_checking)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton(onPressed: _check, child: const Text('Kiểm tra')),
      ],
    ),
  );
}

String _scenarioLabel(String value) => switch (value) {
  'コンビニ' => 'コンビニ · Cửa hàng tiện lợi',
  'レストラン' => 'レストラン · Nhà hàng',
  '学校' => '学校 · Trường học',
  '駅' => '駅 · Nhà ga',
  '面接' => '面接 · Phỏng vấn',
  '旅行' => '旅行 · Du lịch',
  '買い物' => '買い物 · Mua sắm',
  _ => value,
};
