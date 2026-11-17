import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/attendance/domain/models/attendance_log_model.dart';
import 'package:slkc_app/features/attendance/presentation/providers/attendance_admin_provider.dart';
import 'package:slkc_app/features/classes/presentation/providers/class_provider.dart';

/// Screen providing a live, immutable audit trail of all attendance insertions and modifications.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(auditLogFilterProvider);
    final logsAsync = ref.watch(auditLogsProvider);
    final classesAsync = ref.watch(classesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // ── Search & Filter Bar ─────────────────────────────────────────
          Material(
            elevation: 1,
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Search TextField
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by student, class, or modifier...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: filter.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                ref
                                    .read(auditLogFilterProvider.notifier)
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      ref
                          .read(auditLogFilterProvider.notifier)
                          .setSearchQuery(val);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Filter Row: Date + Class
                  Row(
                    children: [
                      // Date Filter Pill
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          filter.date != null
                              ? DateFormat('d MMM yyyy').format(filter.date!)
                              : 'All Dates',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: filter.date ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            ref
                                .read(auditLogFilterProvider.notifier)
                                .setDate(picked);
                          }
                        },
                      ),
                      if (filter.date != null) ...[
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Clear Date Filter',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            ref
                                .read(auditLogFilterProvider.notifier)
                                .setDate(null);
                          },
                        ),
                      ],
                      const SizedBox(width: 8),

                      // Class Filter Dropdown
                      Expanded(
                        child: classesAsync.when(
                          data: (classes) {
                            return DropdownButtonFormField<String?>(
                              value: filter.classId,
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              hint: const Text('All Classes', style: TextStyle(fontSize: 12)),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Classes', style: TextStyle(fontSize: 12)),
                                ),
                                ...classes.map((c) => DropdownMenuItem<String?>(
                                      value: c.id,
                                      child: Text(
                                        c.name,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )),
                              ],
                              onChanged: (newClassId) {
                                ref
                                    .read(auditLogFilterProvider.notifier)
                                    .setClassId(newClassId);
                              },
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Audit Log Feed ──────────────────────────────────────────────
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 56, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'No audit trail records found',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Modifications to attendance are recorded here automatically.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(auditLogsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _AuditLogTile(log: log);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading audit logs:\n${AppErrorHandler.getErrorMessage(e)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detailed visual card displaying an individual audit log entry.
class _AuditLogTile extends StatelessWidget {
  final AttendanceLogModel log;

  const _AuditLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInitial = log.isInitialMark;
    final isAdmin = log.changedByRole == AppConstants.roleAdmin;

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isInitial
              ? Colors.grey.withValues(alpha: 0.3)
              : Colors.amber.withValues(alpha: 0.6),
          width: isInitial ? 0.8 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Student info & Timestamp
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isInitial
                      ? theme.colorScheme.secondaryContainer
                      : Colors.amber.withValues(alpha: 0.2),
                  child: Icon(
                    isInitial ? Icons.create_outlined : Icons.edit_note_rounded,
                    size: 18,
                    color: isInitial
                        ? theme.colorScheme.onSecondaryContainer
                        : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 10),

                // Student name & Class details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Roll: ${log.rollNo} • ${log.className} • ${log.session.toUpperCase()}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      Text(
                        'Date: ${log.date}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // Formatted timestamp
                Text(
                  DateFormat('d MMM, h:mm a').format(log.changedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),

            const Divider(height: 16),

            // Bottom Row: Status Transition Badge & Changed By User
            Row(
              children: [
                // Transition pill
                _buildTransitionWidget(log),

                const Spacer(),

                // Changed by Badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin ? Icons.admin_panel_settings : Icons.school,
                      size: 14,
                      color: isAdmin ? Colors.deepPurple : Colors.blueGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.changedByName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isAdmin ? Colors.deepPurple : Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: (isAdmin ? Colors.deepPurple : Colors.blueGrey)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.changedByRole.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isAdmin ? Colors.deepPurple : Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransitionWidget(AttendanceLogModel log) {
    if (log.isInitialMark) {
      final isPresent = log.newStatus == 'present';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('CREATED', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          const SizedBox(width: 6),
          _statusPill(log.newStatus, isPresent ? Colors.green : Colors.red),
        ],
      );
    } else {
      final oldIsPresent = log.oldStatus == 'present';
      final newIsPresent = log.newStatus == 'present';

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusPill(log.oldStatus ?? '-', oldIsPresent ? Colors.green : Colors.red),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
          ),
          _statusPill(log.newStatus, newIsPresent ? Colors.green : Colors.red),
        ],
      );
    }
  }

  Widget _statusPill(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
