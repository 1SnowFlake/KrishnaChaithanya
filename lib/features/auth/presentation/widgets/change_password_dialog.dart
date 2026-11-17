import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/core/widgets/primary_button.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';

/// Clean, secure dialog allowing any logged-in user (Admin or Staff)
/// to change their account password.
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  /// Static helper to display the dialog from anywhere in the app
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .changePassword(_passwordCtrl.text);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Password updated successfully.'),
              ],
            ),
            backgroundColor: AppColors.present,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.getErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text('Change Password'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a new password for your account. It must be at least 6 characters long.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // New Password
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (val.trim().length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Confirm New Password
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (val != _passwordCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Update Password',
          isFullWidth: false,
          isLoading: _isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
