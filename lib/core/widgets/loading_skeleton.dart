import 'package:flutter/material.dart';
import 'package:slkc_app/core/theme/app_theme.dart';

/// Shimmer-style pulse placeholder built without external packages.
class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppRadius.sm,
    this.margin,
  });

  /// Factory for a standard card skeleton
  static Widget card({double height = 72, EdgeInsetsGeometry? margin}) {
    return LoadingSkeleton(
      width: double.infinity,
      height: height,
      borderRadius: AppRadius.md,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
    );
  }

  /// Factory for a list of card skeletons
  static Widget list({int count = 5}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => card(),
    );
  }

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
