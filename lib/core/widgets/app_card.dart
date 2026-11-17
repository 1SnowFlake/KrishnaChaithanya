import 'package:flutter/material.dart';
import 'package:slkc_app/core/theme/app_theme.dart';

/// Reusable card component adhering to the design system.
/// Supports optional onTap with ink splash, custom padding, border, and background.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final BorderSide? border;
  final double borderRadius;
  final double elevation;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.color,
    this.border,
    this.borderRadius = AppRadius.md,
    this.elevation = AppElevation.none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBorder = BorderSide(
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );

    return Padding(
      padding: margin,
      child: Material(
        color: color ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: border ?? defaultBorder,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
