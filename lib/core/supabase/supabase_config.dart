import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialises the Supabase client.
///
/// Priority:
/// 1. Reads SUPABASE_URL and SUPABASE_ANON_KEY from --dart-define.
/// 2. If not passed (e.g. running directly via F5 in VS Code without args),
///    falls back to the project default credentials so development isn't blocked.
class SupabaseConfig {
  SupabaseConfig._();

  // Project defaults for local development fallback
  static const String _defaultUrl = 'https://cnwcambhldsmvpuwgcqj.supabase.co';
  static const String _defaultAnonKey =
      'sb_publishable_IlAsVPCWoKdFl-Xc5RxaYA_SvftODPl';

  /// Supabase project URL
  static String get url {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    return envUrl.isNotEmpty ? envUrl : _defaultUrl;
  }

  /// Supabase Anon / Publishable key
  static String get anonKey {
    const envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return envAnonKey.isNotEmpty ? envAnonKey : _defaultAnonKey;
  }

  /// Call once in main() before runApp().
  static Future<void> init() async {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    const envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    final url = envUrl.isNotEmpty ? envUrl : _defaultUrl;
    final anonKey = envAnonKey.isNotEmpty ? envAnonKey : _defaultAnonKey;

    debugPrint('Supabase URL: $url');
    debugPrint('Supabase Anon Key length: ${anonKey.length}');

    if (envUrl.isEmpty) {
      debugPrint(
        'Note: SUPABASE_URL not supplied via --dart-define. Using fallback project URL.',
      );
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Shorthand for the global Supabase client.
  static SupabaseClient get client => Supabase.instance.client;
}
