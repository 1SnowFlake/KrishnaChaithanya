import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:slkc_app/features/holidays/domain/models/holiday_model.dart';
import 'package:slkc_app/features/holidays/presentation/providers/holiday_provider.dart';

/// Screen displaying the school holiday calendar.
/// Admins can create, edit, and delete holidays. Teachers have read-only calendar access.
class HolidayListScreen extends ConsumerStatefulWidget {
  const HolidayListScreen({super.key});

  @override
  ConsumerState<HolidayListScreen> createState() => _HolidayListScreenState();
}

class _HolidayListScreenState extends ConsumerState<HolidayListScreen>
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
    final holidaysAsync = ref.watch(holidaysNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;
    final isAdmin = user?.isAdmin ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holiday Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
          indicatorColor: theme.colorScheme.secondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Upcoming & Active'),
            Tab(text: 'All Holidays'),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add Holiday'),
              onPressed: () => _showHolidayDialog(context, null),
            )
          : null,
      body: holidaysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load holidays: ${AppErrorHandler.getErrorMessage(e)}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (allHolidays) {
          final upcoming = allHolidays.where((h) => !h.isPast).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Upcoming & Active
              _buildHolidayList(context, upcoming, isAdmin, isUpcomingTab: true),

              // Tab 2: All Holidays
              _buildHolidayList(context, allHolidays, isAdmin, isUpcomingTab: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHolidayList(
    BuildContext context,
    List<HolidayModel> holidays,
    bool isAdmin, {
    required bool isUpcomingTab,
  }) {
    if (holidays.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 56, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              isUpcomingTab ? 'No upcoming holidays scheduled' : 'No holidays recorded',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(holidaysNotifierProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: holidays.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final holiday = holidays[index];
          return _HolidayCard(
            holiday: holiday,
            isAdmin: isAdmin,
            onEdit: () => _showHolidayDialog(context, holiday),
            onDelete: () => _confirmDelete(context, holiday),
          );
        },
      ),
    );
  }

  Future<void> _showHolidayDialog(BuildContext context, HolidayModel? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime endDate = existing?.endDate ?? DateTime.now();
    bool isRange = existing != null ? !existing.isSingleDay : false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Holiday' : 'Edit Holiday'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Holiday Name *',
                      hintText: 'e.g., Diwali, Independence Day',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Single Day vs Range toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Multi-Day Range'),
                    value: isRange,
                    onChanged: (val) {
                      setDialogState(() {
                        isRange = val;
                        if (!isRange) {
                          endDate = startDate;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // Start Date Picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(isRange ? 'Start Date' : 'Holiday Date'),
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
                          if (!isRange || endDate.isBefore(startDate)) {
                            endDate = startDate;
                          }
                        });
                      }
                    },
                  ),

                  // End Date Picker (if Range)
                  if (isRange) ...[
                    const Divider(),
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
                          setDialogState(() {
                            endDate = picked;
                          });
                        }
                      },
                    ),
                  ],
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
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a holiday name')),
                    );
                    return;
                  }

                  try {
                    if (existing == null) {
                      await ref
                          .read(holidaysNotifierProvider.notifier)
                          .createHoliday(
                            name: name,
                            startDate: startDate,
                            endDate: endDate,
                          );
                    } else {
                      await ref
                          .read(holidaysNotifierProvider.notifier)
                          .updateHoliday(
                            id: existing.id,
                            name: name,
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
                                ? 'Holiday added successfully'
                                : 'Holiday updated successfully',
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
                child: Text(existing == null ? 'Save Holiday' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, HolidayModel holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Are you sure you want to remove "${holiday.name}" from the school calendar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(holidaysNotifierProvider.notifier).deleteHoliday(holiday.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Holiday deleted successfully'),
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

/// Card representing a holiday.
class _HolidayCard extends StatelessWidget {
  final HolidayModel holiday;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HolidayCard({
    required this.holiday,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = holiday.isCurrent;
    final isPast = holiday.isPast;

    final badgeColor = isCurrent
        ? Colors.green
        : (isPast ? Colors.grey : theme.colorScheme.primary);

    return Card(
      elevation: isCurrent ? 2 : 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent
              ? Colors.green
              : (isPast ? Colors.grey.withValues(alpha: 0.2) : Colors.transparent),
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Date block
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMM').format(holiday.startDate).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                  Text(
                    DateFormat('d').format(holiday.startDate),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Holiday Name and Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          holiday.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (isCurrent) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (isPast) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'PASSED',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    holiday.formattedRange,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Admin actions (Edit / Delete)
            if (isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Holiday',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                tooltip: 'Delete Holiday',
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
