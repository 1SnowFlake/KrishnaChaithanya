import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/features/sync/data/local/app_local_database.dart';
import 'package:slkc_app/features/sync/presentation/providers/sync_provider.dart';

/// Manages application-wide ThemeMode (Light, Dark, or System)
/// and persists the user preference in local SQLite.
///
/// DEFAULT: ThemeMode.light on first launch (no saved preference).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final AppLocalDatabase _db;
  static const String _prefKey = 'theme_mode';

  ThemeModeNotifier(this._db) : super(ThemeMode.light) {
    _loadPreference();
  }

  void _loadPreference() {
    try {
      final saved = _db.getPreference(_prefKey);
      if (saved == 'light') {
        state = ThemeMode.light;
      } else if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'system') {
        state = ThemeMode.system;
      }
      // If null (first launch), state stays ThemeMode.light (the super() default).
    } catch (_) {
      // Keep default light on any read error.
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    try {
      final val = mode == ThemeMode.light
          ? 'light'
          : (mode == ThemeMode.dark ? 'dark' : 'system');
      _db.setPreference(_prefKey, val);
    } catch (_) {}
  }

  /// Convenience toggle: Light ↔ Dark (skips System).
  void toggleTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return ThemeModeNotifier(db);
});
