import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/report_provider.dart';

/// Renders the searchable and filterable student breakdown table.
class StudentReportTable extends ConsumerWidget {
  final double threshold;

  const StudentReportTable({
    super.key,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(reportFilterProvider);
    final filterNotifier = ref.read(reportFilterProvider.notifier);
    final students = ref.watch(filteredStudentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by student name or roll no...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: filter.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => filterNotifier.setSearchQuery(''),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (val) => filterNotifier.setSearchQuery(val),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: filter.filterLowOnly ? Colors.white : Colors.amber.shade800,
              ),
              label: Text('< ${threshold.toStringAsFixed(0)}%'),
              selected: filter.filterLowOnly,
              selectedColor: Colors.amber.shade800,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: filter.filterLowOnly ? Colors.white : Colors.amber.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              onSelected: (_) => filterNotifier.toggleFilterLowOnly(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Result count header
        Text(
          'Showing ${students.length} student${students.length == 1 ? "" : "s"}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        if (students.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 40, color: theme.colorScheme.outline),
                const SizedBox(height: 8),
                Text(
                  'No students match the current filters.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = students[index];
              final isLow = s.isLowAttendance(threshold);
              final pct = s.attendancePercentage;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isLow
                        ? Colors.amber.shade400
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: isLow ? 1.5 : 1.0,
                  ),
                ),
                color: isLow
                    ? Colors.amber.shade50.withValues(alpha: 0.5)
                    : theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Roll Number Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isLow
                            ? Colors.amber.shade100
                            : theme.colorScheme.primaryContainer,
                        child: Text(
                          s.rollNo,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isLow
                                ? Colors.amber.shade900
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name and Class
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.studentName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.className}  |  ${s.presentCount}/${s.totalSessions} sessions present',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Percentage and Alert Badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLow ? Colors.amber.shade700 : Colors.green.shade700,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (isLow) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 13, color: Colors.amber.shade900),
                                const SizedBox(width: 2),
                                Text(
                                  'Low attendance',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
