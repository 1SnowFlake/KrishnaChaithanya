import 'package:flutter/material.dart';
import 'package:slkc_app/core/theme/app_theme.dart';

enum StatusChipType {
  present,
  absent,
  holiday,
  online,
  offline,
  syncing,
  substitute,
}

/// Accessible status chip with both icon + text and high contrast background/foreground.
class StatusChip extends StatelessWidget {
  final StatusChipType type;
  final String? customLabel;
  final bool isCompact;

  const StatusChip({
    super.key,
    required this.type,
    this.customLabel,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (type) {
      case StatusChipType.present:
        bg = isDark ? AppColors.presentSurfaceDark : AppColors.presentSurface;
        fg = isDark ? AppColors.presentDark : AppColors.present;
        icon = Icons.check_circle_rounded;
        label = customLabel ?? 'Present';
        break;
      case StatusChipType.absent:
        bg = isDark ? AppColors.absentSurfaceDark : AppColors.absentSurface;
        fg = isDark ? AppColors.absentDark : AppColors.absent;
        icon = Icons.cancel_rounded;
        label = customLabel ?? 'Absent';
        break;
      case StatusChipType.holiday:
        bg = isDark ? const Color(0xFF2C1B3D) : AppColors.holidaySurface;
        fg = isDark ? const Color(0xFFCE93D8) : AppColors.holiday;
        icon = Icons.event_busy_rounded;
        label = customLabel ?? 'Holiday';
        break;
      case StatusChipType.online:
        bg = isDark ? AppColors.presentSurfaceDark : AppColors.presentSurface;
        fg = isDark ? AppColors.presentDark : AppColors.present;
        icon = Icons.cloud_done_rounded;
        label = customLabel ?? 'Online';
        break;
      case StatusChipType.offline:
        bg = isDark ? const Color(0xFF3B2014) : AppColors.offlineSurface;
        fg = isDark ? const Color(0xFFFFAB91) : AppColors.offline;
        icon = Icons.cloud_off_rounded;
        label = customLabel ?? 'Offline';
        break;
      case StatusChipType.syncing:
        bg = isDark ? const Color(0xFF102A43) : AppColors.syncingSurface;
        fg = isDark ? const Color(0xFF90CAF9) : AppColors.syncing;
        icon = Icons.sync_rounded;
        label = customLabel ?? 'Syncing...';
        break;
      case StatusChipType.substitute:
        bg = isDark ? const Color(0xFF142C4C) : AppColors.substituteSurface;
        fg = isDark ? const Color(0xFF90CAF9) : AppColors.substitute;
        icon = Icons.swap_horiz_rounded;
        label = customLabel ?? 'Substitute';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 14 : 16, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
