import 'package:flutter/material.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/widgets/primary_button.dart';

/// Standard empty state illustration + title + message + action button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onAction;
  final IconData? buttonIcon;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onAction,
    this.buttonIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (buttonLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: buttonLabel!,
                icon: buttonIcon ?? Icons.add,
                onPressed: onAction,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
