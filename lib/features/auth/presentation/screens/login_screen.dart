import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';

/// Clean mobile-first Login Screen.
/// Authenticates the user with Supabase Auth using email and password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await ref.read(authNotifierProvider.notifier).login(email, password);

    // If an error occurred, show a friendly SnackBar
    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState.hasError) {
      final message = AppErrorHandler.getErrorMessage(authState.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App branding icon
                  Icon(
                    Icons.school_rounded,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'School Attendance',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your account',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Email Input Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'e.g. teacher@school.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password Input Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    // Seed credentials hint card for easy testing
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Test Credentials (Seed)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Admin: admin@school.com\nTeacher: teacher1@school.com\nPassword: Test@123',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

