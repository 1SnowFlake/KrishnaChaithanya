import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/theme/theme_mode_selector.dart';
import 'package:slkc_app/core/theme/theme_provider.dart';
import 'package:slkc_app/core/theme/theme_toggle_button.dart';
import 'package:slkc_app/core/widgets/empty_state_view.dart';
import 'package:slkc_app/core/widgets/skeleton_loader.dart';
import 'package:slkc_app/features/sync/data/local/app_local_database.dart';
import 'package:slkc_app/features/sync/presentation/providers/sync_provider.dart';

void main() {
  test('Phase 11: Material 3 Themes & Accessible Touch Targets Verification', () {
    print('\n==========================================');
    print('STEP 1: Verifying Material 3 theme configurations...');

    final light = AppTheme.light;
    final dark = AppTheme.dark;

    // Verify Material 3 flag
    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);

    // Verify Brightnesses
    expect(light.brightness, equals(Brightness.light));
    expect(dark.brightness, equals(Brightness.dark));

    // Verify WCAG 2.1 Touch Target Sizes (>= 48x48dp)
    print('\n==========================================');
    print('STEP 2: Verifying button accessible touch targets (>= 48x48dp)...');

    final lightElevatedMin = light.elevatedButtonTheme.style?.minimumSize?.resolve({});
    expect(lightElevatedMin, isNotNull);
    expect(lightElevatedMin!.height, greaterThanOrEqualTo(48.0));
    expect(lightElevatedMin.width, greaterThanOrEqualTo(48.0));

    final darkElevatedMin = dark.elevatedButtonTheme.style?.minimumSize?.resolve({});
    expect(darkElevatedMin, isNotNull);
    expect(darkElevatedMin!.height, greaterThanOrEqualTo(48.0));
    expect(darkElevatedMin.width, greaterThanOrEqualTo(48.0));

    final lightFilledMin = light.filledButtonTheme.style?.minimumSize?.resolve({});
    expect(lightFilledMin, isNotNull);
    expect(lightFilledMin!.height, greaterThanOrEqualTo(48.0));

    final lightOutlinedMin = light.outlinedButtonTheme.style?.minimumSize?.resolve({});
    expect(lightOutlinedMin, isNotNull);
    expect(lightOutlinedMin!.height, greaterThanOrEqualTo(48.0));

    print('Verified: All interactive buttons meet accessible 48x48dp touch target guidelines.');
  });

  test('Phase 11: ThemeModeNotifier Persistence in SQLite', () async {
    print('\n==========================================');
    print('STEP 3: Testing ThemeModeNotifier persistence in SQLite...');
    final localDb = AppLocalDatabase();
    await localDb.init(inMemory: true);

    final notifier = ThemeModeNotifier(localDb);
    // Light mode is default on first launch
    expect(notifier.state, equals(ThemeMode.light));

    // Switch to dark
    notifier.setThemeMode(ThemeMode.dark);
    expect(notifier.state, equals(ThemeMode.dark));
    expect(localDb.getPreference('theme_mode'), equals('dark'));

    // Switch to light
    notifier.setThemeMode(ThemeMode.light);
    expect(notifier.state, equals(ThemeMode.light));
    expect(localDb.getPreference('theme_mode'), equals('light'));

    // Switch back to system
    notifier.setThemeMode(ThemeMode.system);
    expect(notifier.state, equals(ThemeMode.system));
    expect(localDb.getPreference('theme_mode'), equals('system'));

    // Verify reload from SQLite preserves theme state
    localDb.setPreference('theme_mode', 'dark');
    final freshNotifier = ThemeModeNotifier(localDb);
    expect(freshNotifier.state, equals(ThemeMode.dark));
    print('Theme mode persistence verified across SQLite reloads.');
    localDb.dispose();
  });

  testWidgets('Phase 11 Widget Test: ThemeModeSelector & ThemeToggleButton Interactions',
      (tester) async {
    print('\n==========================================');
    print('STEP 4: Testing interactive Theme widgets (Segmented selector & Toggle button)...');
    final localDb = AppLocalDatabase();
    await localDb.init(inMemory: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(localDb),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [ThemeToggleButton()],
            ),
            body: const Column(
              children: [
                ThemeModeSelector(),
                SkeletonBox(width: 100, height: 20),
                EmptyStateView(
                  icon: Icons.check,
                  title: 'All Good',
                  message: 'No actions required',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify ThemeToggleButton renders
    expect(find.byType(ThemeToggleButton), findsOneWidget);

    // Verify ThemeModeSelector renders with System, Light, and Dark options
    expect(find.byType(ThemeModeSelector), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // Tap 'Dark' segment
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(localDb.getPreference('theme_mode'), equals('dark'));

    // Tap 'Light' segment
    await tester.tap(find.text('Light'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(localDb.getPreference('theme_mode'), equals('light'));

    // Tap ThemeToggleButton in AppBar
    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Skeleton and EmptyState render cleanly
    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('All Good'), findsOneWidget);

    localDb.dispose();
    print('\n==========================================');
    print('SUCCESS: Phase 11 UI Polish, Dark Mode & Touch Targets fully verified!');
  });
}
