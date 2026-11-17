import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/auth/domain/models/user_profile.dart';

/// Handles authentication operations with Supabase Auth
/// and fetches the linked user profile from the `profiles` table.
class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  /// Stream of Supabase Auth state changes (sign in, sign out, token refreshed).
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Currently logged-in Supabase Auth user, if any.
  User? get currentUser => _supabase.auth.currentUser;

  /// Currently active session, if any.
  Session? get currentSession => _supabase.auth.currentSession;

  /// Sign in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out current user.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Updates the password of the currently authenticated user.
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword.trim()),
    );
  }

  /// Fetches the profile record for the given [userId] from `profiles` table.
  /// Returns null if not found.
  Future<UserProfile?> fetchProfile(String userId) async {
    final response = await _supabase
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserProfile.fromMap(response);
  }
}

