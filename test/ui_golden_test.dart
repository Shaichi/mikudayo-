import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mikudayo/app/app.dart';
import 'package:mikudayo/data/repositories/settings_repository.dart';

void main() {
  Future<void> pumpPhoneApp(WidgetTester tester, Key boundaryKey) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(
      await SharedPreferences.getInstance(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
        child: RepaintBoundary(key: boundaryKey, child: const MikuApp()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('golden - trang chủ kích thước điện thoại', (tester) async {
    const boundaryKey = ValueKey('app-boundary');
    await pumpPhoneApp(tester, boundaryKey);

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/home_screen.png'),
    );
  });

  testWidgets('golden - thiết lập buổi học', (tester) async {
    const boundaryKey = ValueKey('app-boundary');
    await pumpPhoneApp(tester, boundaryKey);
    await tester.tap(find.byTooltip('Mở cài đặt'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/settings_screen.png'),
    );
  });

  testWidgets('trang chủ và cài đặt không tràn khi tăng cỡ chữ', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const boundaryKey = ValueKey('app-boundary');
    await pumpPhoneApp(tester, boundaryKey);

    await tester.tap(find.byTooltip('Mở cài đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết lập buổi học'), findsOneWidget);
  });
}
