import 'package:flutter/material.dart';

/// Animated skeleton loading placeholder with a subtle opacity pulse.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
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

/// Standard skeleton placeholder for cards (e.g. classes, students, or attendance lists).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonBox(width: 44, height: 44, borderRadius: 22),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 16),
                  SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 12),
                ],
              ),
            ),
            SizedBox(width: 12),
            SkeletonBox(width: 60, height: 28, borderRadius: 14),
          ],
        ),
      ),
    );
  }
}

/// Stack of skeleton cards for loading states.
class SkeletonList extends StatelessWidget {
  final int count;

  const SkeletonList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonCard(),
    );
  }
}
