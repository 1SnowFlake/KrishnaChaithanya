import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

/// Single-tap AppBar action button that toggles between Light and Dark modes.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
      onPressed: () {
        ref.read(themeModeProvider.notifier).setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
      },
    );
  }
}
