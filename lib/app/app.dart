import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/app/router.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/theme/theme_provider.dart';

/// Root application widget.
/// Consumes [routerProvider] to enable reactive role-based navigation.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'School Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
