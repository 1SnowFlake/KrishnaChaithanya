import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/features/classes/presentation/providers/class_provider.dart';
import '../../data/services/csv_export_service.dart';
import '../../data/services/pdf_export_service.dart';
import '../providers/report_provider.dart';
import '../widgets/attendance_trend_chart.dart';
import '../widgets/report_kpi_card.dart';
import '../widgets/student_report_table.dart';

/// Full reporting and analytics dashboard with date filters, trend charts,
/// low attendance alerts, and cross-platform PDF/CSV exporting.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;

  Future<void> _exportCsv() async {
    final reportAsync = ref.read(attendanceReportProvider);
    final summary = reportAsync.value;
    if (summary == null) return;

    setState(() => _isExporting = true);
    try {
      await CsvExportService.exportAndShareCsv(summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf() async {
    final reportAsync = ref.read(attendanceReportProvider);
    final summary = reportAsync.value;
    if (summary == null) return;

    setState(() => _isExporting = true);
    try {
      await PdfExportService.exportAndPrintPdf(summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final filter = ref.read(reportFilterProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: filter.startDate,
        end: filter.endDate,
      ),
    );

    if (picked != null) {
      ref.read(reportFilterProvider.notifier).setCustomDateRange(
            picked.start,
            picked.end,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(reportFilterProvider);
    final filterNotifier = ref.read(reportFilterProvider.notifier);
    final classesAsync = ref.watch(classesNotifierProvider);
    final reportAsync = ref.watch(attendanceReportProvider);

    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports & Analytics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Attendance trends & threshold analysis',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Export CSV Spreadsheet',
              icon: const Icon(Icons.table_view_outlined),
              onPressed: reportAsync.hasValue ? _exportCsv : null,
            ),
            IconButton(
              tooltip: 'Print / Save PDF Report',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: reportAsync.hasValue ? _exportPdf : null,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendanceReportProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // FILTER SECTION
              // ==========================================
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Class Selector
                      classesAsync.when(
                        data: (classes) {
                          return DropdownButtonFormField<String?>(
                            value: filter.classId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Target Class',
                              prefixIcon: const Icon(Icons.class_outlined, size: 20),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Classes (Whole School)'),
                              ),
                              ...classes.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: (newClassId) {
                              filterNotifier.setClassId(newClassId);
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 12),

                      // Date Preset Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Last 7 Days'),
                              selected: filter.datePreset == ReportDatePreset.last7Days,
                              onSelected: (_) =>
                                  filterNotifier.setDatePreset(ReportDatePreset.last7Days),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Last 30 Days'),
                              selected: filter.datePreset == ReportDatePreset.last30Days,
                              onSelected: (_) =>
                                  filterNotifier.setDatePreset(ReportDatePreset.last30Days),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('This Month'),
                              selected: filter.datePreset == ReportDatePreset.thisMonth,
                              onSelected: (_) =>
                                  filterNotifier.setDatePreset(ReportDatePreset.thisMonth),
                            ),
                            const SizedBox(width: 6),
                            ActionChip(
                              avatar: const Icon(Icons.date_range, size: 16),
                              label: Text(
                                filter.datePreset == ReportDatePreset.custom
                                    ? '${dateFormat.format(filter.startDate)} - ${dateFormat.format(filter.endDate)}'
                                    : 'Custom Range...',
                              ),
                              onPressed: () => _pickCustomDateRange(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Session Segmented Button
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'all',
                              label: Text('Both Sessions'),
                              icon: Icon(Icons.access_time_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: 'morning',
                              label: Text('Morning'),
                              icon: Icon(Icons.wb_sunny_outlined, size: 16),
                            ),
                            ButtonSegment(
                              value: 'afternoon',
                              label: Text('Afternoon'),
                              icon: Icon(Icons.wb_twilight_outlined, size: 16),
                            ),
                          ],
                          selected: {filter.session},
                          onSelectionChanged: (newSelection) {
                            filterNotifier.setSession(newSelection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // REPORT CONTENT
              // ==========================================
              reportAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text('Failed to load report data: $err'),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(attendanceReportProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (summary) {
                  final isGoodOverall = summary.overallPercentage >= summary.threshold;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI CARDS ROW
                      Row(
                        children: [
                          Expanded(
                            child: ReportKpiCard(
                              title: 'Attendance Rate',
                              value: '${summary.overallPercentage.toStringAsFixed(1)}%',
                              icon: Icons.pie_chart_outline_rounded,
                              color: isGoodOverall ? Colors.green.shade700 : Colors.red.shade700,
                              subtitle: '${summary.totalPresent} / ${summary.totalSessions} present',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ReportKpiCard(
                              title: 'Total Sessions',
                              value: '${summary.totalSessions}',
                              icon: Icons.checklist_rounded,
                              color: theme.colorScheme.primary,
                              subtitle: '${summary.totalStudents} students evaluated',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ReportKpiCard(
                              title: 'Below Threshold',
                              value: '${summary.lowAttendanceCount}',
                              icon: Icons.warning_amber_rounded,
                              color: summary.lowAttendanceCount > 0
                                  ? Colors.amber.shade800
                                  : Colors.green.shade700,
                              subtitle: '< ${summary.threshold.toStringAsFixed(0)}% required',
                              onTap: () {
                                if (!filter.filterLowOnly) {
                                  filterNotifier.toggleFilterLowOnly();
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // TREND CHART HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Attendance Trend Over Time',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag_outlined, size: 12, color: Colors.amber.shade900),
                                const SizedBox(width: 4),
                                Text(
                                  'Threshold: ${summary.threshold.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // TREND CHART WIDGET
                      AttendanceTrendChart(
                        trends: summary.dailyTrends,
                        threshold: summary.threshold,
                      ),

                      const SizedBox(height: 24),

                      // STUDENT BREAKDOWN SECTION
                      Text(
                        'Student Breakdown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // STUDENT TABLE
                      StudentReportTable(
                        threshold: summary.threshold,
                      ),

                      const SizedBox(height: 32),

                      // BOTTOM EXPORT ACTIONS
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.table_view_outlined),
                              label: const Text('Export CSV'),
                              onPressed: _isExporting ? null : _exportCsv,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Print / Export PDF'),
                              onPressed: _isExporting ? null : _exportPdf,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
