import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper utility that translates raw technical errors and exceptions
/// into human-friendly messages for the UI.
class AppErrorHandler {
  AppErrorHandler._();

  /// Converts any caught exception into a simple readable error string.
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';

    if (error is AuthException) {
      switch (error.statusCode) {
        case '400':
        case '500':
          final msg = error.message.toLowerCase();
          if (msg.contains('invalid login credentials')) {
            return 'Invalid email or password. Please try again.';
          }
          if (msg.contains('user already registered') || msg.contains('already registered')) {
            return 'An account with this email address already exists.';
          }
          if (msg.contains('database error saving new user')) {
            return 'Database error: Please run migration 007_fix_staff_role_constraint.sql in your Supabase SQL Editor to allow this role.';
          }
          return error.message;
        case '422':
          return 'Invalid input: ${error.message}';
        case '429':
          return 'Too many attempts. Please wait a few moments before trying again.';
        default:
          return error.message;
      }
    } else if (error is FunctionException) {
      if (error.details != null) {
        if (error.details is Map && error.details['error'] != null) {
          return error.details['error'].toString();
        }
        return error.details.toString();
      }
      if (error.status == 404) {
        return 'Edge function "create-teacher" not deployed on Supabase (404).';
      }
      return error.reasonPhrase ?? 'Function invocation failed (${error.status}).';
    } else if (error is PostgrestException) {
      if (error.code == 'PGRST116') {
        return 'Profile record not found. Please contact the administrator.';
      }
      if (error.code == '23505') {
        return 'A record with this information already exists.';
      }
      return error.message;
    } else if (error.toString().toLowerCase().contains('failed to fetch') ||
               error.toString().contains('ClientException')) {
      return 'Connection failed (Failed to fetch). If running in Chrome, launch with `--web-browser-flag=--ignore-certificate-errors` to allow campus firewall certificates.';
    } else if (error.toString().contains('SocketException') ||
               error.toString().contains('Failed host lookup') ||
               error.toString().contains('NetworkException')) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (error is Exception) {
      final msg = error.toString().replaceFirst('Exception: ', '').trim();
      if (msg.isNotEmpty) return msg;
    }

    // Default fallback
    final str = error.toString();
    return str.isNotEmpty ? str : 'An unexpected error occurred. Please try again.';
  }
}
