import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/core/widgets/skeleton_loader.dart';
import 'package:slkc_app/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:slkc_app/features/sync/presentation/widgets/offline_banner.dart';

/// Screen where teachers mark and toggle attendance for a class session.
class TakeAttendanceScreen extends ConsumerWidget {
  final String classId;
  final String className;
  final String session; // 'morning' | 'afternoon'
  final bool isEdit;

  const TakeAttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.session,
    this.isEdit = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = AttendanceParams(classId: classId, session: session);
    final draftState = ref.watch(attendanceDraftNotifierProvider(params));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sessionLabel =
        session[0].toUpperCase() + session.substring(1).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$className · $sessionLabel'),
            Text(
              isEdit ? 'Editing Today\'s Attendance' : 'Marking Attendance',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(attendanceDraftNotifierProvider(params)),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: draftState.when(
              loading: () => const SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: SkeletonList(count: 6),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(
                        AppErrorHandler.getErrorMessage(err),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(attendanceDraftNotifierProvider(params)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (draft) {
                if (draft.students.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'No Active Students',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No active students found in this class.\nPlease contact the administrator.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final notifier =
                    ref.read(attendanceDraftNotifierProvider(params).notifier);

                // Semantic color: use lighter tint on dark backgrounds
                final presentColor =
                    isDark ? AppColors.presentDark : AppColors.present;
                final absentColor =
                    isDark ? AppColors.absentDark : AppColors.absent;
                final presentSurface = isDark
                    ? AppColors.presentSurfaceDark
                    : AppColors.presentSurface;
                final absentSurface =
                    isDark ? AppColors.absentSurfaceDark : AppColors.absentSurface;

                return Column(
                  children: [
                    // ── Substitute badge ─────────────────────────────
                    if (draft.isSubstitute) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        color: isDark
                            ? AppColors.substituteSurface.withValues(alpha: 0.15)
                            : AppColors.substituteSurface,
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz,
                                size: 18, color: AppColors.substitute),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You are marking attendance as an authorised Substitute Teacher.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.substitute,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Summary + Quick Actions ──────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Live stats row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatChip(
                                label: 'Total',
                                count: draft.students.length,
                                color: theme.colorScheme.onSurface,
                                icon: Icons.people_outline,
                              ),
                              _buildStatChip(
                                label: 'Present',
                                count: draft.presentCount,
                                color: presentColor,
                                icon: Icons.check_circle_outline,
                              ),
                              _buildStatChip(
                                label: 'Absent',
                                count: draft.absentCount,
                                color: absentColor,
                                icon: Icons.cancel_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quick action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: presentColor,
                                    side: BorderSide(color: presentColor),
                                  ),
                                  icon:
                                      const Icon(Icons.done_all, size: 18),
                                  label: const Text('All Present'),
                                  onPressed: () => notifier.markAllPresent(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: absentColor,
                                    side: BorderSide(color: absentColor),
                                  ),
                                  icon: const Icon(Icons.clear_all, size: 18),
                                  label: const Text('All Absent'),
                                  onPressed: () => notifier.markAllAbsent(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Student List ─────────────────────────────────
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: draft.students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final student = draft.students[index];
                          final status = draft.statuses[student.id] ??
                              AppConstants.statusPresent;
                          final isPresent =
                              status == AppConstants.statusPresent;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isPresent
                                    ? presentColor.withValues(alpha: 0.4)
                                    : absentColor.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            color: isPresent ? presentSurface : absentSurface,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => notifier.toggleStudent(student.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    // Roll badge
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isPresent
                                          ? presentColor.withValues(alpha: 0.2)
                                          : absentColor.withValues(alpha: 0.2),
                                      child: Text(
                                        student.rollNo,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isPresent
                                              ? presentColor
                                              : absentColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Name
                                    Expanded(
                                      child: Text(
                                        student.name,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),

                                    // Status badge (icon + text — not color-only)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isPresent
                                            ? presentColor
                                            : absentColor,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPresent
                                                ? Icons.check
                                                : Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isPresent ? 'PRESENT' : 'ABSENT',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Submit Button ────────────────────────────────
                    SafeArea(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            minimumSize:
                                const Size(double.infinity, 52),
                          ),
                          onPressed: draft.isSubmitting
                              ? null
                              : () => _openConfirmation(
                                  context, ref, draft, params),
                          child: draft.isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Review & Submit Attendance',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _openConfirmation(
    BuildContext context,
    WidgetRef ref,
    AttendanceDraftState draft,
    AttendanceParams params,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final presentColor = isDark ? AppColors.presentDark : AppColors.present;
    final absentColor  = isDark ? AppColors.absentDark  : AppColors.absent;
    final presentSurface = isDark ? AppColors.presentSurfaceDark : AppColors.presentSurface;
    final absentSurface  = isDark ? AppColors.absentSurfaceDark  : AppColors.absentSurface;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.fact_check_outlined,
                color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Confirm Submission'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$className · ${session[0].toUpperCase()}${session.substring(1)} Session',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),

            // Present / Absent summary boxes
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: presentSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: presentColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_circle_outline, size: 14, color: presentColor),
                          const SizedBox(width: 4),
                          Text('${draft.presentCount}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: presentColor)),
                        ]),
                        Text('Present',
                            style:
                                TextStyle(fontSize: 11, color: presentColor)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: absentSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: absentColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.cancel_outlined, size: 14, color: absentColor),
                          const SizedBox(width: 4),
                          Text('${draft.absentCount}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: absentColor)),
                        ]),
                        Text('Absent',
                            style:
                                TextStyle(fontSize: 11, color: absentColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Absent students list
            if (draft.absentStudents.isNotEmpty) ...[
              Text('Students marked absent:',
                  style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView(
                  shrinkWrap: true,
                  children: draft.absentStudents
                      .map((s) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• Roll ${s.rollNo}: ${s.name}',
                                style: theme.textTheme.bodySmall),
                          ))
                      .toList(),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: presentSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: presentColor, size: 16),
                    const SizedBox(width: 6),
                    Text('All students marked Present!',
                        style: TextStyle(
                            color: presentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(attendanceDraftNotifierProvider(params).notifier)
          .submit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Attendance submitted successfully!'),
            backgroundColor: AppColors.present,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.getErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
