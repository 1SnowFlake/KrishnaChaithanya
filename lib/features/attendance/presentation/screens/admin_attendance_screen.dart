import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/attendance/domain/models/attendance_admin_record.dart';
import 'package:slkc_app/features/attendance/presentation/providers/attendance_admin_provider.dart';
import 'package:slkc_app/features/classes/presentation/providers/class_provider.dart';
import 'package:slkc_app/features/teachers/presentation/widgets/teacher_attendance_view.dart';

/// Admin Screen to view and modify student & teacher attendance for ANY date and ANY session.
class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  int _selectedTarget = 0; // 0 = Students, 1 = Teachers

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminAttendanceFilterProvider);
    final classesAsync = ref.watch(classesProvider);
    final recordsAsync = ref.watch(adminAttendanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // ── Category Selector: Students vs Teachers ─────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface,
            child: Center(
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Students Attendance'),
                    icon: Icon(Icons.school_outlined, size: 16),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Staff Attendance'),
                    icon: Icon(Icons.badge_outlined, size: 16),
                  ),
                ],
                selected: {_selectedTarget},
                onSelectionChanged: (val) {
                  setState(() {
                    _selectedTarget = val.first;
                  });
                },
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Body: Teacher Attendance View OR Student Attendance Controls ───
          if (_selectedTarget == 1)
            const Expanded(child: TeacherAttendanceView())
          else ...[
            // ── Top Control & Filter Panel (Students) ───────────────────
            Material(
              elevation: 2,
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Row 1: Date Selector & Session Switcher
                  Row(
                    children: [
                      // Date Selector Pill
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text(
                            DateFormat('EEE, d MMM yyyy').format(filter.date),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: filter.date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              ref
                                  .read(adminAttendanceFilterProvider.notifier)
                                  .setDate(picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Session Segmented Button
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: AppConstants.sessionMorning,
                            label: Text(
                              'Morning',
                              style: TextStyle(fontSize: 12),
                            ),
                            icon: Icon(Icons.wb_sunny_outlined, size: 16),
                          ),
                          ButtonSegment(
                            value: AppConstants.sessionAfternoon,
                            label: Text(
                              'Afternoon',
                              style: TextStyle(fontSize: 12),
                            ),
                            icon: Icon(Icons.wb_twilight_outlined, size: 16),
                          ),
                        ],
                        selected: {filter.session},
                        onSelectionChanged: (newSelection) {
                          ref
                              .read(adminAttendanceFilterProvider.notifier)
                              .setSession(newSelection.first);
                        },
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 2: Class Picker Dropdown
                  classesAsync.when(
                    data: (classes) {
                      return DropdownButtonFormField<String>(
                        key: ValueKey('admin_class_picker_${filter.classId}'),
                        value:
                            (filter.classId != null &&
                                classes.any((c) => c.id == filter.classId))
                            ? filter.classId
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Select Class',
                          prefixIcon: const Icon(Icons.school_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        hint: const Text('Choose a class to view/edit'),
                        items: classes.map((cls) {
                          return DropdownMenuItem<String>(
                            value: cls.id,
                            child: Text(cls.name),
                          );
                        }).toList(),
                        onChanged: (newClassId) {
                          ref
                              .read(adminAttendanceFilterProvider.notifier)
                              .setClassId(newClassId);
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      'Failed to load classes: ${AppErrorHandler.getErrorMessage(e)}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Stats Summary & Batch Quick Actions ─────────────────────────
          recordsAsync.when(
            data: (records) {
              if (filter.classId == null) {
                return const SizedBox.shrink();
              }

              final total = records.length;
              final present = records.where((r) => r.isPresent).length;
              final absent = records.where((r) => r.isAbsent).length;
              final unmarked = total - present - absent;

              return Container(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildStatPill('Present', present, Colors.green),
                    const SizedBox(width: 8),
                    _buildStatPill('Absent', absent, Colors.red),
                    const SizedBox(width: 8),
                    if (unmarked > 0) ...[
                      _buildStatPill('Unmarked', unmarked, Colors.grey),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),

                    // Batch actions popup
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Batch Actions',
                      onSelected: (val) async {
                        try {
                          await ref
                              .read(adminAttendanceProvider.notifier)
                              .markAll(val);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Class marked all ${val.toUpperCase()} successfully',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppErrorHandler.getErrorMessage(e),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: AppConstants.statusPresent,
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text('Mark All Present'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: AppConstants.statusAbsent,
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Mark All Absent'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Main Student Attendance Records List ────────────────────────
          Expanded(
            child: filter.classId == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 48,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select a class above to review or modify attendance',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : recordsAsync.when(
                    data: (records) {
                      if (records.isEmpty) {
                        return const Center(
                          child: Text(
                            'No active students found in this class.',
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(adminAttendanceProvider);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return _AdminStudentAttendanceTile(record: record);
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error loading attendance:\n${AppErrorHandler.getErrorMessage(e)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// List tile representing an individual student's attendance record with direct Admin toggle.
class _AdminStudentAttendanceTile extends ConsumerWidget {
  final AttendanceAdminRecord record;

  const _AdminStudentAttendanceTile({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPresent = record.isPresent;
    final isAbsent = record.isAbsent;
    final isUnmarked = !record.isMarked;

    final Color statusColor = isPresent
        ? Colors.green
        : (isAbsent ? Colors.red : Colors.grey);

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withValues(alpha: isUnmarked ? 0.2 : 0.4),
          width: 1.2,
        ),
      ),
      color: statusColor.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Roll No Badge
            CircleAvatar(
              radius: 18,
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Text(
                record.rollNo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Student Name & Last Modification info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUnmarked
                        ? 'Not yet marked'
                        : 'Marked by: ${record.markedByName ?? 'Unknown'}${record.updatedAt != null ? ' (${DateFormat('h:mm a').format(record.updatedAt!)})' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Status Badge + Tap-to-toggle Button
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                try {
                  await ref
                      .read(adminAttendanceProvider.notifier)
                      .toggleStatus(record);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppErrorHandler.getErrorMessage(e)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPresent
                          ? Icons.check
                          : (isAbsent ? Icons.close : Icons.help_outline),
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPresent
                          ? 'PRESENT'
                          : (isAbsent ? 'ABSENT' : 'UNMARKED'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
