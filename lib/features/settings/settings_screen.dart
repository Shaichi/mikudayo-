import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import '../../data/services/api_service.dart';

const _modes = ['free_talk', 'correction', 'roleplay'];
const _levels = ['N5', 'N4', 'N3'];
const _scenarios = [
  '',
  'コンビニ',
  'レストラン',
  '学校',
  '駅',
  '面接',
  '旅行',
  '買い物',
];

/// Màn hình Cài đặt — server URL, mode, JLPT level, scenario.
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

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _serverCtrl = TextEditingController(text: s.serverUrl);
    _mode = s.mode;
    _level = s.jlptLevel;
    _scenario = s.scenario;
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var url = _serverCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    if (url.isEmpty) url = 'https://mikudayo.onrender.com';
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.update(AppSettings(
      serverUrl: url,
      mode: _mode,
      jlptLevel: _level,
      scenario: _scenario,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu cài đặt ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Server URL ---
          Text('Máy chủ', style: _sectionStyle(scheme)),
          const SizedBox(height: 8),
          TextField(
            controller: _serverCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://mikudayo.onrender.com',
              labelText: 'Địa chỉ backend',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Desktop/Web dùng 127.0.0.1. Điện thoại cùng Wi-Fi: dùng IP máy, '
            'ví dụ http://192.168.1.10:8000 (backend chạy với --host 0.0.0.0). '
            'Emulator Android dùng http://10.0.2.2:8000.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // --- Mode ---
          Text('Chế độ học', style: _sectionStyle(scheme)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in _modes) _choiceChip(
                    label: _modeLabel(m),
                    selected: _mode == m,
                    onSelected: () => setState(() => _mode = m),
                  ),
            ],
          ),
          const SizedBox(height: 24),

          // --- JLPT Level ---
          Text('Cấp độ JLPT', style: _sectionStyle(scheme)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final l in _levels)
                _choiceChip(
                  label: l,
                  selected: _level == l,
                  onSelected: () => setState(() => _level = l),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Scenario ---
          Text('Bối cảnh (Role Play)', style: _sectionStyle(scheme)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _scenario,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: [
              for (final s in _scenarios)
                DropdownMenuItem(
                  value: s,
                  child: Text(s.isEmpty ? 'Tự do (không bối cảnh)' : s),
                ),
            ],
            onChanged: (v) => setState(() => _scenario = v ?? ''),
          ),
          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu cài đặt'),
          ),
          const SizedBox(height: 24),

          // --- Health check ---
          _HealthCheckCard(),
        ],
      ),
    );
  }

  TextStyle _sectionStyle(ColorScheme scheme) => TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: scheme.primary,
      );

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  String _modeLabel(String m) => switch (m) {
        'free_talk' => 'Tự do',
        'correction' => 'Sửa lỗi',
        'roleplay' => 'Đóng vai',
        _ => m,
      };
}

/// Thẻ kiểm tra kết nối backend + health.
class _HealthCheckCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HealthCheckCard> createState() => _HealthCheckCardState();
}

class _HealthCheckCardState extends ConsumerState<_HealthCheckCard> {
  bool _checking = false;
  String _result = 'Chưa kiểm tra';

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = 'Đang kiểm tra…';
    });
    final serverUrl = ref.read(appSettingsProvider).serverUrl;
    try {
      final res = await ref.read(apiServiceProvider).health(serverUrl);
      if (!mounted) return;
      setState(() {
        _result = res;
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = '⚠ Không kết nối được: $e';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.monitor_heart_outlined),
        title: const Text('Kiểm tra máy chủ'),
        subtitle: Text(_result, style: const TextStyle(fontSize: 12.5)),
        trailing: _checking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton.tonal(
                onPressed: _check,
                child: const Text('Kiểm tra'),
              ),
      ),
    );
  }
}
