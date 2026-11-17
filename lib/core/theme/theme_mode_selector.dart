import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

/// Interactive segmented selector allowing the user to switch between System, Light, and Dark themes.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Appearance & Theme',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined, size: 18),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 18),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 18),
                label: Text('Dark'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (newSelection) {
              notifier.setThemeMode(newSelection.first);
            },
          ),
        ),
      ],
    );
  }
}
