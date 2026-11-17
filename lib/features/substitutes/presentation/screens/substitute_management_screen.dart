import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/classes/presentation/providers/class_provider.dart';
import 'package:slkc_app/features/substitutes/domain/models/substitute_assignment_model.dart';
import 'package:slkc_app/features/substitutes/presentation/providers/substitute_provider.dart';
import 'package:slkc_app/features/teachers/presentation/providers/teacher_provider.dart';

/// Screen allowing school administrators to assign and manage substitute teachers.
class SubstituteManagementScreen extends ConsumerStatefulWidget {
  const SubstituteManagementScreen({super.key});

  @override
  ConsumerState<SubstituteManagementScreen> createState() =>
      _SubstituteManagementScreenState();
}

class _SubstituteManagementScreenState
    extends ConsumerState<SubstituteManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final substitutesAsync = ref.watch(substitutesNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Substitute Teacher Assignments',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
          indicatorColor: theme.colorScheme.secondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Active & Upcoming'),
            Tab(text: 'Past Assignments'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Assign Substitute'),
        onPressed: () => _showAssignmentDialog(context, null),
      ),
      body: substitutesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load substitute assignments:\n${AppErrorHandler.getErrorMessage(e)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (assignments) {
          final activeAndUpcoming =
              assignments.where((a) => !a.isPast).toList();
          final past = assignments.where((a) => a.isPast).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAssignmentList(context, activeAndUpcoming, isPastTab: false),
              _buildAssignmentList(context, past, isPastTab: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAssignmentList(
    BuildContext context,
    List<SubstituteAssignmentModel> list, {
    required bool isPastTab,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_ind_outlined,
                size: 56, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              isPastTab
                  ? 'No past substitute assignments'
                  : 'No active or upcoming substitute assignments',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(substitutesNotifierProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = list[index];
          return _SubstituteCard(
            item: item,
            onEdit: () => _showAssignmentDialog(context, item),
            onDelete: () => _confirmDelete(context, item),
          );
        },
      ),
    );
  }

  Future<void> _showAssignmentDialog(
    BuildContext context,
    SubstituteAssignmentModel? existing,
  ) async {
    final classes = ref.read(classesProvider).value ?? [];
    final teachers = ref.read(teachersProvider).value ?? [];

    String? selectedClassId = existing?.classId ??
        (classes.isNotEmpty ? classes.first.id : null);
    String? selectedTeacherId = existing?.teacherId ??
        (teachers.isNotEmpty ? teachers.first.id : null);
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime endDate = existing?.endDate ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Assign Substitute Teacher' : 'Edit Assignment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class Selection Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Select Class *',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: classes.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedClassId = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Substitute Teacher Selection Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedTeacherId,
                    decoration: const InputDecoration(
                      labelText: 'Substitute Teacher *',
                      prefixIcon: Icon(Icons.person_pin_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: teachers.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.name} (${t.email})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedTeacherId = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Start Date Picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Start Date'),
                    subtitle: Text(DateFormat('EEEE, d MMM yyyy').format(startDate)),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDate = picked;
                          if (endDate.isBefore(startDate)) {
                            endDate = startDate;
                          }
                        });
                      }
                    },
                  ),

                  // End Date Picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('End Date'),
                    subtitle: Text(DateFormat('EEEE, d MMM yyyy').format(endDate)),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                        firstDate: startDate,
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedClassId == null || selectedTeacherId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select both a class and teacher')),
                    );
                    return;
                  }

                  try {
                    if (existing == null) {
                      await ref
                          .read(substitutesNotifierProvider.notifier)
                          .createAssignment(
                            classId: selectedClassId!,
                            teacherId: selectedTeacherId!,
                            startDate: startDate,
                            endDate: endDate,
                          );
                    } else {
                      await ref
                          .read(substitutesNotifierProvider.notifier)
                          .updateAssignment(
                            id: existing.id,
                            classId: selectedClassId!,
                            teacherId: selectedTeacherId!,
                            startDate: startDate,
                            endDate: endDate,
                          );
                    }

                    if (context.mounted) {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existing == null
                                ? 'Substitute assigned successfully'
                                : 'Assignment updated successfully',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
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
                child: Text(existing == null ? 'Assign' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SubstituteAssignmentModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: Text(
          'Revoke substitute assignment for ${item.teacherName} in ${item.className}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(substitutesNotifierProvider.notifier)
            .deleteAssignment(item.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Substitute assignment revoked successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
    }
  }
}

/// Visual card displaying a substitute assignment.
class _SubstituteCard extends StatelessWidget {
  final SubstituteAssignmentModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubstituteCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = item.isActiveToday;
    final isUpcoming = item.isUpcoming;

    final Color badgeColor = isActive
        ? Colors.green
        : (isUpcoming ? Colors.blue : Colors.grey);

    return Card(
      elevation: isActive ? 2 : 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.green : Colors.transparent,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar Icon
            CircleAvatar(
              radius: 20,
              backgroundColor: badgeColor.withValues(alpha: 0.15),
              child: Icon(
                Icons.swap_horiz_rounded,
                color: badgeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Class & Teacher details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.className,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          isActive
                              ? 'ACTIVE TODAY'
                              : (isUpcoming ? 'UPCOMING' : 'EXPIRED'),
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Teacher: ${item.teacherName}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    'Duration: ${item.formattedRange}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Admin actions
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit Assignment',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'Revoke Assignment',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
