import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/auth/data/repositories/auth_repository.dart';
import 'package:slkc_app/features/auth/domain/models/user_profile.dart';

/// Provides the singleton instance of [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(SupabaseConfig.client);
});

/// Stream of auth state changes emitted by Supabase.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

/// Manages authentication state and current user profile.
class AuthNotifier extends AsyncNotifier<UserProfile?> {
  late final AuthRepository _repository;
  StreamSubscription<AuthState>? _sub;

  @override
  FutureOr<UserProfile?> build() async {
    _repository = ref.watch(authRepositoryProvider);

    // Cancel existing subscription if any on rebuild
    _sub?.cancel();
    _sub = _repository.authStateChanges.listen((event) async {
      final user = event.session?.user;
      if (user == null) {
        state = const AsyncData(null);
      } else {
        // Fetch or refresh profile whenever auth event fires
        state = await AsyncValue.guard(() => _repository.fetchProfile(user.id));
      }
    });

    ref.onDispose(() {
      _sub?.cancel();
    });

    // Check initial session
    final initialUser = _repository.currentUser;
    if (initialUser == null) {
      return null;
    }

    return await _repository.fetchProfile(initialUser.id);
  }

  /// Logs in with email and password, then loads the profile.
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _repository.signIn(email: email, password: password);
      final user = response.user;
      if (user == null) return null;
      return await _repository.fetchProfile(user.id);
    });
  }

  /// Logs out of Supabase and resets state to null.
  Future<void> logout() async {
    state = const AsyncLoading();
    await _repository.signOut();
    state = const AsyncData(null);
  }

  /// Updates the password of the currently authenticated user.
  Future<void> changePassword(String newPassword) async {
    await _repository.updatePassword(newPassword);
  }
}

/// Provider for [AuthNotifier].
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, UserProfile?>(AuthNotifier.new);

/// Listenable that notifies GoRouter when the auth state changes.
class AuthRouterListenable extends ChangeNotifier {
  AuthRouterListenable(Ref ref) {
    ref.listen<AsyncValue<UserProfile?>>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final authRouterListenableProvider = Provider<AuthRouterListenable>((ref) {
  return AuthRouterListenable(ref);
});

