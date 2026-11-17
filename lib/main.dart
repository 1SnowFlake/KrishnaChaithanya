import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/app/app.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';

/// Entry point for the School Attendance App.
///
/// Run with:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
void main() async {
  // Required before calling any plugin (Supabase, notifications, etc.)
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to Supabase using --dart-define values.
  await SupabaseConfig.init();

  // Root must be wrapped in ProviderScope for Riverpod
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
