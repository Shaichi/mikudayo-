// Widget test cơ bản — kiểm tra app Miku khởi động và hiển thị màn hình chính.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikudayo/app/app.dart';
import 'package:mikudayo/data/repositories/settings_repository.dart';

void main() {
  testWidgets('MikuApp hiển thị màn hình chính', (WidgetTester tester) async {
    // Cung cấp SharedPreferences giả cho môi trường test.
    SharedPreferences.setMockInitialValues({});

    final repo = SettingsRepository(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: const MikuApp(),
      ),
    );

    // Màn hình chính ưu tiên hành động luyện nói và không lộ thuật ngữ nội bộ.
    expect(find.text('ミクと話そう'), findsOneWidget);
    expect(find.text('Nói chuyện với Miku'), findsOneWidget);
    expect(find.text('Không gian học tập'), findsOneWidget);
    expect(find.text('Từ vựng'), findsOneWidget);
    expect(find.textContaining('Phase'), findsNothing);
  });
}
