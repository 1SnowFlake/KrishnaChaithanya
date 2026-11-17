import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/report_repository.dart';
import '../../domain/models/report_models.dart';

/// Predefined date filter ranges for easy single-tap switching.
enum ReportDatePreset {
  last7Days,
  last30Days,
  thisMonth,
  custom,
}

/// Filter criteria for attendance reports.
class ReportFilterState {
  final DateTime startDate;
  final DateTime endDate;
  final ReportDatePreset datePreset;
  final String? classId;
  final String session; // 'all', 'morning', 'afternoon'
  final bool filterLowOnly;
  final String searchQuery;

  ReportFilterState({
    required this.startDate,
    required this.endDate,
    this.datePreset = ReportDatePreset.last7Days,
    this.classId,
    this.session = 'all',
    this.filterLowOnly = false,
    this.searchQuery = '',
  });

  factory ReportFilterState.initial() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));

    return ReportFilterState(
      startDate: sevenDaysAgo,
      endDate: today,
      datePreset: ReportDatePreset.last7Days,
    );
  }

  ReportFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    ReportDatePreset? datePreset,
    String? classId,
    bool clearClassId = false,
    String? session,
    bool? filterLowOnly,
    String? searchQuery,
  }) {
    return ReportFilterState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      datePreset: datePreset ?? this.datePreset,
      classId: clearClassId ? null : (classId ?? this.classId),
      session: session ?? this.session,
      filterLowOnly: filterLowOnly ?? this.filterLowOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Notifier managing filter state.
class ReportFilterNotifier extends StateNotifier<ReportFilterState> {
  ReportFilterNotifier() : super(ReportFilterState.initial());

  void setDatePreset(ReportDatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime start;
    switch (preset) {
      case ReportDatePreset.last7Days:
        start = today.subtract(const Duration(days: 6));
        break;
      case ReportDatePreset.last30Days:
        start = today.subtract(const Duration(days: 29));
        break;
      case ReportDatePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case ReportDatePreset.custom:
        return; // Retain current dates or user opens picker
    }

    state = state.copyWith(
      startDate: start,
      endDate: today,
      datePreset: preset,
    );
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    state = state.copyWith(
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day),
      datePreset: ReportDatePreset.custom,
    );
  }

  void setClassId(String? classId) {
    if (classId == null || classId.isEmpty) {
      state = state.copyWith(clearClassId: true);
    } else {
      state = state.copyWith(classId: classId);
    }
  }

  void setSession(String session) {
    state = state.copyWith(session: session);
  }

  void toggleFilterLowOnly() {
    state = state.copyWith(filterLowOnly: !state.filterLowOnly);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final reportFilterProvider =
    StateNotifierProvider<ReportFilterNotifier, ReportFilterState>((ref) {
  return ReportFilterNotifier();
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

/// Fetches the aggregated attendance report matching active filters.
final attendanceReportProvider =
    FutureProvider.autoDispose<AttendanceReportSummary>((ref) async {
  final filter = ref.watch(reportFilterProvider);
  final repository = ref.watch(reportRepositoryProvider);

  return repository.getAttendanceReport(
    startDate: filter.startDate,
    endDate: filter.endDate,
    classId: filter.classId,
    session: filter.session == 'all' ? null : filter.session,
  );
});

/// Returns the student list filtered by the search query and the low-attendance flag.
final filteredStudentsProvider =
    Provider.autoDispose<List<StudentAttendanceReport>>((ref) {
  final reportAsync = ref.watch(attendanceReportProvider);
  final filter = ref.watch(reportFilterProvider);

  return reportAsync.maybeWhen(
    data: (summary) {
      return summary.students.where((student) {
        // 1. Low attendance filter
        if (filter.filterLowOnly && !student.isLowAttendance(summary.threshold)) {
          return false;
        }

        // 2. Search query filter (matches student name or roll number)
        if (filter.searchQuery.trim().isNotEmpty) {
          final query = filter.searchQuery.toLowerCase().trim();
          final nameMatches = student.studentName.toLowerCase().contains(query);
          final rollMatches = student.rollNo.toLowerCase().contains(query);
          if (!nameMatches && !rollMatches) {
            return false;
          }
        }

        return true;
      }).toList();
    },
    orElse: () => [],
  );
});
