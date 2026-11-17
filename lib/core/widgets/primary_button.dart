import 'package:flutter/material.dart';
import 'package:slkc_app/core/theme/app_theme.dart';

/// Primary action button with minimum 48x48 tap target and built-in loading spinner.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final buttonChild = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ?? theme.colorScheme.onPrimary,
              ),
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );

    final buttonStyle = FilledButton.styleFrom(
      minimumSize: Size(isFullWidth ? double.infinity : 48, 48),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
    );

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle,
      child: buttonChild,
    );
  }
}
