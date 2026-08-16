import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cài đặt người dùng (server URL, mode, level, scenario).
///
/// Lưu cục bộ bằng shared_preferences; gửi kèm mỗi lượt hội thoại.
class AppSettings {
  const AppSettings({
    this.serverUrl = 'https://mikudayo.onrender.com',
    this.mode = 'free_talk',
    this.jlptLevel = 'N5',
    this.scenario = '',
  });

  final String serverUrl;
  final String mode;
  final String jlptLevel;
  final String scenario;

  AppSettings copyWith({
    String? serverUrl,
    String? mode,
    String? jlptLevel,
    String? scenario,
  }) =>
      AppSettings(
        serverUrl: serverUrl ?? this.serverUrl,
        mode: mode ?? this.mode,
        jlptLevel: jlptLevel ?? this.jlptLevel,
        scenario: scenario ?? this.scenario,
      );

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'mode': mode,
        'jlptLevel': jlptLevel,
        'scenario': scenario,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        serverUrl: (json['serverUrl'] as String?) ?? 'https://mikudayo.onrender.com',
        mode: (json['mode'] as String?) ?? 'free_talk',
        jlptLevel: (json['jlptLevel'] as String?) ?? 'N5',
        scenario: (json['scenario'] as String?) ?? '',
      );
}

/// Repository đọc/ghi cài đặt local.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'app_settings';

  AppSettings load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}

/// Provider cho repository — được override trong `main()` sau khi
/// `SharedPreferences` sẵn sàng (xem `lib/main.dart`).
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('Override trong main()'),
);
