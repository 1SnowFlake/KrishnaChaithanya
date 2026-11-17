import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/core/widgets/app_card.dart';
import 'package:slkc_app/core/widgets/empty_state.dart';
import 'package:slkc_app/core/widgets/error_state.dart';
import 'package:slkc_app/core/widgets/loading_skeleton.dart';
import 'package:slkc_app/features/teachers/domain/models/teacher_attendance_model.dart';
import 'package:slkc_app/features/teachers/presentation/providers/teacher_attendance_provider.dart';

/// Full-featured view for Admin to take and review Staff & Teacher attendance
/// across all roles (Teacher, Assistant Teacher, Warden, Cook, Aya, Watchman,
/// Psychologist, Dance Master, Doctor, Psychotherapist, and custom roles).
class TeacherAttendanceView extends ConsumerStatefulWidget {
  const TeacherAttendanceView({super.key});

  @override
  ConsumerState<TeacherAttendanceView> createState() =>
      _TeacherAttendanceViewState();
}

class _TeacherAttendanceViewState extends ConsumerState<TeacherAttendanceView> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRoleFilter; // null = all roles

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(teacherAttendanceFilterProvider);
    final attendanceAsync = ref.watch(teacherAttendanceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // ── Controls Header: Date, Session, Search & Role Filter ─────
        Material(
          elevation: 1,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Date Selector Button
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
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
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
                                .read(teacherAttendanceFilterProvider.notifier)
                                .setDate(picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Session Segmented Switch
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: AppConstants.sessionMorning,
                          label: Text('Morning', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.wb_sunny_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: AppConstants.sessionAfternoon,
                          label: Text('Afternoon', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.wb_twilight_outlined, size: 16),
                        ),
                      ],
                      selected: {filter.session},
                      onSelectionChanged: (newSelection) {
                        ref
                            .read(teacherAttendanceFilterProvider.notifier)
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
                const SizedBox(height: AppSpacing.sm),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search staff by name, role, or email...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(teacherAttendanceFilterProvider.notifier)
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (val) {
                    ref
                        .read(teacherAttendanceFilterProvider.notifier)
                        .setSearchQuery(val.trim());
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Horizontal Role Filter Pills
                attendanceAsync.when(
                  data: (records) {
                    final roles = records.map((r) => r.role).toSet().toList()..sort();
                    if (roles.length <= 1) return const SizedBox.shrink();

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text('All Staff (${records.length})'),
                            selected: _selectedRoleFilter == null,
                            onSelected: (_) {
                              setState(() => _selectedRoleFilter = null);
                            },
                          ),
                          const SizedBox(width: 6),
                          ...roles.map((r) {
                            final count = records.where((rec) => rec.role == r).length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text('$r ($count)'),
                                selected: _selectedRoleFilter == r,
                                onSelected: (sel) {
                                  setState(() {
                                    _selectedRoleFilter = sel ? r : null;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),

        // ── Stats Summary & Batch Quick Actions ─────────────────────
        attendanceAsync.when(
          data: (allRecords) {
            // Apply role filter to stats
            final records = _selectedRoleFilter == null
                ? allRecords
                : allRecords.where((r) => r.role == _selectedRoleFilter).toList();

            final total = records.length;
            final present = records.where((r) => r.isPresent).length;
            final absent = records.where((r) => r.isAbsent).length;
            final unmarked = total - present - absent;

            return Container(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _buildStatPill('Present', present, AppColors.present, isDark),
                  const SizedBox(width: AppSpacing.sm),
                  _buildStatPill('Absent', absent, AppColors.absent, isDark),
                  const SizedBox(width: AppSpacing.sm),
                  if (unmarked > 0) ...[
                    _buildStatPill(
                      'Unmarked',
                      unmarked,
                      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      isDark,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  const Spacer(),

                  // Batch actions popup (marks current filtered group)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Batch Actions',
                    onSelected: (val) async {
                      try {
                        for (final r in records) {
                          if (r.status != val) {
                            await ref
                                .read(teacherAttendanceProvider.notifier)
                                .toggleStatus(r);
                          }
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${_selectedRoleFilter ?? 'All staff'} marked ${val.toUpperCase()} successfully',
                              ),
                              backgroundColor: val == AppConstants.statusPresent
                                  ? AppColors.present
                                  : AppColors.absent,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppErrorHandler.getErrorMessage(e)),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: AppConstants.statusPresent,
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: AppColors.present, size: 18),
                            const SizedBox(width: 8),
                            Text(_selectedRoleFilter == null
                                ? 'Mark All Present'
                                : 'Mark ${_selectedRoleFilter}s Present'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: AppConstants.statusAbsent,
                        child: Row(
                          children: [
                            Icon(Icons.cancel_rounded,
                                color: AppColors.absent, size: 18),
                            const SizedBox(width: 8),
                            Text(_selectedRoleFilter == null
                                ? 'Mark All Absent'
                                : 'Mark ${_selectedRoleFilter}s Absent'),
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

        // ── Main List of Staff Attendance Cards ─────────────────────
        Expanded(
          child: attendanceAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: LoadingSkeleton.list(count: 6),
            ),
            error: (err, _) => ErrorState(
              message: AppErrorHandler.getErrorMessage(err),
              onRetry: () =>
                  ref.read(teacherAttendanceProvider.notifier).loadAttendance(),
            ),
            data: (allRecords) {
              final query = filter.searchQuery.toLowerCase();
              final filtered = allRecords.where((r) {
                // Role filter
                if (_selectedRoleFilter != null && r.role != _selectedRoleFilter) {
                  return false;
                }
                // Text search query
                if (query.isEmpty) return true;
                return r.teacherName.toLowerCase().contains(query) ||
                    r.role.toLowerCase().contains(query) ||
                    r.teacherEmail.toLowerCase().contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No Staff Found',
                  message: query.isNotEmpty
                      ? 'No staff members matched "$query".'
                      : (_selectedRoleFilter != null
                          ? 'No staff found with role "$_selectedRoleFilter".'
                          : 'No active staff members found in the directory.'),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref
                    .read(teacherAttendanceProvider.notifier)
                    .loadAttendance(),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    return _TeacherAttendanceTile(record: record);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatPill(
      String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
        ),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Card Tile for any staff member's attendance with role badge & tap-to-toggle
class _TeacherAttendanceTile extends ConsumerWidget {
  final TeacherAttendanceModel record;

  const _TeacherAttendanceTile({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isPresent = record.isPresent;
    final isAbsent = record.isAbsent;
    final isUnmarked = !record.isMarked;

    Color statusColor;
    Color statusBg;
    if (isPresent) {
      statusColor = isDark ? AppColors.presentDark : AppColors.present;
      statusBg = isDark ? AppColors.presentSurfaceDark : AppColors.presentSurface;
    } else if (isAbsent) {
      statusColor = isDark ? AppColors.absentDark : AppColors.absent;
      statusBg = isDark ? AppColors.absentSurfaceDark : AppColors.absentSurface;
    } else {
      statusColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      statusBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    }

    final initials = record.teacherName.isNotEmpty
        ? record.teacherName
            .trim()
            .split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join()
        : 'S';

    return AppCard(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: BorderSide(
        color: isUnmarked
            ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
            : statusColor.withValues(alpha: 0.5),
        width: isUnmarked ? 1.0 : 1.5,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: () async {
        HapticFeedback.lightImpact();
        try {
          await ref
              .read(teacherAttendanceProvider.notifier)
              .toggleStatus(record);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppErrorHandler.getErrorMessage(e)),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        }
      },
      child: Row(
        children: [
          // Initials Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Name, Email, Role Tag & Last Marked info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.teacherName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Specific Role Badge (Teacher, Warden, Cook, Aya, Doctor, etc.)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: record.role.toLowerCase() == 'admin'
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: record.role.toLowerCase() == 'admin'
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        record.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: record.role.toLowerCase() == 'admin'
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                if (record.teacherEmail.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    record.teacherEmail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  isUnmarked
                      ? 'Not yet marked'
                      : 'Marked by: ${record.markedByName ?? 'Admin'}${record.updatedAt != null ? ' (${DateFormat('h:mm a').format(record.updatedAt!)})' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Tap-to-toggle Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPresent
                      ? Icons.check_circle_rounded
                      : (isAbsent
                          ? Icons.cancel_rounded
                          : Icons.help_outline_rounded),
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 5),
                Text(
                  isPresent
                      ? 'PRESENT'
                      : (isAbsent ? 'ABSENT' : 'UNMARKED'),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
