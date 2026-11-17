import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/theme/theme_mode_selector.dart';
import 'package:slkc_app/core/theme/theme_toggle_button.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/core/widgets/skeleton_loader.dart';
import 'package:slkc_app/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:slkc_app/features/auth/presentation/widgets/change_password_dialog.dart';
import 'package:slkc_app/features/classes/domain/models/class_model.dart';
import 'package:slkc_app/features/holidays/presentation/screens/holiday_list_screen.dart';
import 'package:slkc_app/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:slkc_app/features/reports/presentation/screens/reports_screen.dart';
import 'package:slkc_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:slkc_app/features/substitutes/presentation/providers/substitute_provider.dart';
import 'package:slkc_app/features/sync/presentation/widgets/offline_banner.dart';

/// Full Teacher Dashboard.
/// Displays assigned classes, today's holiday/off status, session completion chips,
/// and buttons to take or edit today's morning and afternoon attendance.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).value;
    final classesAsync = ref.watch(teacherClassesProvider);
    final closureAsync = ref.watch(schoolClosureProvider);
    final theme = Theme.of(context);
    final todayStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teacher Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              profile?.name ?? 'Teacher',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          const NotificationBellButton(),
          IconButton(
            tooltip: 'Reports & Analytics',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Holiday Calendar',
            icon: const Icon(Icons.event_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HolidayListScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Profile & Settings',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _openTeacherSettings(context, ref),
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
          ref.invalidate(teacherClassesProvider);
          ref.invalidate(schoolClosureProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date Card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      todayStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Holiday / Weekly Off Alert Banner (if school closed)
            closureAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (closure) {
                if (!closure.isClosed) return const SizedBox.shrink();
                final settings = ref.watch(settingsNotifierProvider).value;
                final allowHoliday = settings?.allowHolidayAttendance ?? true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: allowHoliday
                        ? Colors.amber.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: allowHoliday
                          ? Colors.amber.shade700
                          : Colors.red.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allowHoliday ? Icons.beach_access_rounded : Icons.block_rounded,
                        color: allowHoliday ? Colors.amber.shade800 : Colors.red.shade700,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              closure.reason ?? 'School Closed',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: allowHoliday ? Colors.amber.shade900 : Colors.red.shade900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              allowHoliday
                                  ? 'Attendance marking permitted (Admin special override active).'
                                  : 'Attendance submissions are closed on non-working days.',
                              style: TextStyle(
                                fontSize: 12,
                                color: allowHoliday ? Colors.amber.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Text(
              'My Assigned Classes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Assigned Classes List
            classesAsync.when(
              loading: () => const SkeletonList(count: 3),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppErrorHandler.getErrorMessage(err),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              data: (classes) {
                if (classes.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No classes assigned to you.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Contact the school admin to assign you as a primary or substitute teacher.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final isSchoolClosed = closureAsync.value?.isClosed ?? false;

                return Column(
                  children: classes
                      .map(
                        (cls) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TeacherClassCard(
                            classModel: cls,
                            isSchoolClosed: isSchoolClosed,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }

  void _openTeacherSettings(BuildContext context, WidgetRef ref) {
    final profile = ref.read(authNotifierProvider).value;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.person, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Teacher',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          profile?.email ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              const ThemeModeSelector(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Update your account login password'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ChangePasswordDialog.show(context);
                },
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.logout, color: theme.colorScheme.error),
                  label: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    ref.read(authNotifierProvider.notifier).logout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card showing status and actions for a teacher's assigned class.
class _TeacherClassCard extends ConsumerWidget {
  final ClassModel classModel;
  final bool isSchoolClosed;

  const _TeacherClassCard({
    required this.classModel,
    required this.isSchoolClosed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(classSessionStatusProvider(classModel.id));
    final settings = ref.watch(settingsNotifierProvider).value;
    final subClassIds = ref.watch(teacherSubstituteClassIdsProvider);
    final isSubstitute = subClassIds.contains(classModel.id);
    final allowHoliday = settings?.allowHolidayAttendance ?? true;
    final allowPastCutoff = settings?.allowPastCutoff ?? true;
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Title Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Text(
                    classModel.name.isNotEmpty ? classModel.name[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              classModel.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                          ),
                          if (isSubstitute) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'SUBSTITUTE',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${classModel.studentCount} Students Enrolled',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Session Statuses & Actions
            statusAsync.when(
              loading: () => const SizedBox(
                height: 90,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Text(
                'Could not load session status: $e',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
              data: (status) {
                return Column(
                  children: [
                    // Morning Session Row
                    _buildSessionRow(
                      context: context,
                      sessionName: 'Morning Session',
                      sessionKey: AppConstants.sessionMorning,
                      isSubmitted: status.morningSubmitted,
                      presentCount: status.morningPresent,
                      absentCount: status.morningAbsent,
                      isCutoffPassed: status.morningCutoffPassed,
                      isSchoolClosed: isSchoolClosed,
                      allowHoliday: allowHoliday,
                      allowPastCutoff: allowPastCutoff,
                    ),
                    const SizedBox(height: 10),

                    // Afternoon Session Row
                    _buildSessionRow(
                      context: context,
                      sessionName: 'Afternoon Session',
                      sessionKey: AppConstants.sessionAfternoon,
                      isSubmitted: status.afternoonSubmitted,
                      presentCount: status.afternoonPresent,
                      absentCount: status.afternoonAbsent,
                      isCutoffPassed: status.afternoonCutoffPassed,
                      isSchoolClosed: isSchoolClosed,
                      allowHoliday: allowHoliday,
                      allowPastCutoff: allowPastCutoff,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionRow({
    required BuildContext context,
    required String sessionName,
    required String sessionKey,
    required bool isSubmitted,
    required int presentCount,
    required int absentCount,
    required bool isCutoffPassed,
    required bool isSchoolClosed,
    required bool allowHoliday,
    required bool allowPastCutoff,
  }) {
    bool canTake = true;
    String? blockReason;

    if (isSchoolClosed && !allowHoliday) {
      canTake = false;
      blockReason = 'School is closed';
    } else if (isCutoffPassed && !allowPastCutoff) {
      canTake = false;
      blockReason = 'Cutoff passed (Admin only)';
    }

    final subtitleText = isSubmitted
        ? 'Marked: $presentCount Present, $absentCount Absent'
        : (blockReason ?? 'Pending submission');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final presentColor = isDark ? AppColors.presentDark : AppColors.present;
    final presentSurface = isDark ? AppColors.presentSurfaceDark : AppColors.presentSurface;

    final subtitleColor = isSubmitted
        ? presentColor
        : (canTake ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSubmitted
            ? presentSurface
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Session icon + title
          Icon(
            sessionKey == AppConstants.sessionMorning
                ? Icons.wb_sunny_outlined
                : Icons.wb_twilight_outlined,
            size: 20,
            color: isSubmitted ? presentColor : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),

          // Action Button (Take / Edit)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSubmitted ? presentColor : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            onPressed: !canTake
                ? null
                : () {
                    context.push(
                      AppConstants.pathTeacherAttendance,
                      extra: {
                        'classId': classModel.id,
                        'className': classModel.name,
                        'session': sessionKey,
                        'isEdit': isSubmitted,
                      },
                    );
                  },
            child: Text(
              isSubmitted ? 'Edit Today' : 'Take',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
