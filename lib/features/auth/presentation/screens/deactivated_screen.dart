import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';

/// Screen displayed when an authenticated user has been deactivated by an admin.
class DeactivatedScreen extends ConsumerWidget {
  const DeactivatedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 80,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Account Deactivated',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your school account is currently deactivated.\nPlease contact the school administrator for assistance.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

