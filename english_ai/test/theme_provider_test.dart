import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:english_ai/core/services/storage_service.dart';
import 'package:english_ai/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('new users default to light mode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(StorageService.getThemeMode(), 'light');
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('saved dark mode is preserved and can be reset to light', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(StorageService.getThemeMode(), 'dark');

    await container.read(themeModeProvider.notifier).resetToDefault();
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(StorageService.getThemeMode(), 'light');
  });
}
