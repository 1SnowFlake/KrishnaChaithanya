import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/attendance/data/repositories/attendance_admin_repository.dart';
import 'package:slkc_app/features/attendance/domain/models/attendance_admin_record.dart';
import 'package:slkc_app/features/attendance/domain/models/attendance_log_model.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';

final attendanceAdminRepositoryProvider = Provider<AttendanceAdminRepository>((ref) {
  return AttendanceAdminRepository();
});

/// Filter state for Admin Attendance modification screen.
class AdminAttendanceFilter {
  final DateTime date;
  final String? classId;
  final String session;

  const AdminAttendanceFilter({
    required this.date,
    this.classId,
    required this.session,
  });

  String get dateString => DateFormat('yyyy-MM-dd').format(date);

  AdminAttendanceFilter copyWith({
    DateTime? date,
    String? classId,
    String? session,
  }) {
    return AdminAttendanceFilter(
      date: date ?? this.date,
      classId: classId ?? this.classId,
      session: session ?? this.session,
    );
  }
}

class AdminAttendanceFilterNotifier extends Notifier<AdminAttendanceFilter> {
  @override
  AdminAttendanceFilter build() {
    return AdminAttendanceFilter(
      date: DateTime.now(),
      classId: null,
      session: AppConstants.sessionMorning,
    );
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void setClassId(String? classId) {
    state = state.copyWith(classId: classId);
  }

  void setSession(String session) {
    state = state.copyWith(session: session);
  }
}

final adminAttendanceFilterProvider =
    NotifierProvider<AdminAttendanceFilterNotifier, AdminAttendanceFilter>(
  AdminAttendanceFilterNotifier.new,
);

/// State notifier that manages the list of attendance records for the selected class/date/session,
/// allowing instant optimistic updates and sync with Supabase.
class AdminAttendanceNotifier
    extends AutoDisposeAsyncNotifier<List<AttendanceAdminRecord>> {
  @override
  Future<List<AttendanceAdminRecord>> build() async {
    final filter = ref.watch(adminAttendanceFilterProvider);
    if (filter.classId == null || filter.classId!.isEmpty) {
      return [];
    }

    final repo = ref.watch(attendanceAdminRepositoryProvider);
    return repo.getClassAttendance(
      classId: filter.classId!,
      date: filter.dateString,
      session: filter.session,
    );
  }

  /// Toggles a student's status between 'present' and 'absent'.
  Future<void> toggleStatus(AttendanceAdminRecord record) async {
    final newStatus = record.isPresent
        ? AppConstants.statusAbsent
        : AppConstants.statusPresent;

    final profile = ref.read(authNotifierProvider).value;
    if (profile == null) throw Exception('Admin not authenticated');

    final repo = ref.read(attendanceAdminRepositoryProvider);

    // Optimistic update
    final currentList = state.value ?? [];
    state = AsyncData(
      currentList.map((r) {
        if (r.studentId == record.studentId) {
          return r.copyWith(
            status: newStatus,
            markedBy: profile.id,
            markedByName: profile.name,
            updatedAt: DateTime.now(),
          );
        }
        return r;
      }).toList(),
    );

    try {
      await repo.saveStudentAttendance(
        record: record,
        newStatus: newStatus,
        adminId: profile.id,
      );
      // Invalidate audit logs so they refresh live
      ref.invalidate(auditLogsProvider);
      // Re-fetch clean state
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      // Revert on error
      ref.invalidateSelf();
      rethrow;
    }
  }

  /// Sets all students to a given status ('present' or 'absent').
  Future<void> markAll(String newStatus) async {
    final records = state.value ?? [];
    if (records.isEmpty) return;

    final profile = ref.read(authNotifierProvider).value;
    if (profile == null) throw Exception('Admin not authenticated');

    final repo = ref.read(attendanceAdminRepositoryProvider);

    // Optimistic update
    state = AsyncData(
      records.map((r) {
        return r.copyWith(
          status: newStatus,
          markedBy: profile.id,
          markedByName: profile.name,
          updatedAt: DateTime.now(),
        );
      }).toList(),
    );

    try {
      await repo.batchSetClassAttendance(
        records: records,
        newStatus: newStatus,
        adminId: profile.id,
      );
      ref.invalidate(auditLogsProvider);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncError(e, st);
      ref.invalidateSelf();
      rethrow;
    }
  }
}

final adminAttendanceProvider = AutoDisposeAsyncNotifierProvider<
    AdminAttendanceNotifier, List<AttendanceAdminRecord>>(
  AdminAttendanceNotifier.new,
);

/// Filter state for Audit Log viewer.
class AuditLogFilter {
  final DateTime? date;
  final String? classId;
  final String searchQuery;

  const AuditLogFilter({
    this.date,
    this.classId,
    this.searchQuery = '',
  });

  String? get dateString =>
      date != null ? DateFormat('yyyy-MM-dd').format(date!) : null;

  AuditLogFilter copyWith({
    DateTime? date,
    bool clearDate = false,
    String? classId,
    bool clearClass = false,
    String? searchQuery,
  }) {
    return AuditLogFilter(
      date: clearDate ? null : (date ?? this.date),
      classId: clearClass ? null : (classId ?? this.classId),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class AuditLogFilterNotifier extends Notifier<AuditLogFilter> {
  @override
  AuditLogFilter build() => const AuditLogFilter();

  void setDate(DateTime? date) {
    if (date == null) {
      state = state.copyWith(clearDate: true);
    } else {
      state = state.copyWith(date: date);
    }
  }

  void setClassId(String? classId) {
    if (classId == null) {
      state = state.copyWith(clearClass: true);
    } else {
      state = state.copyWith(classId: classId);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = const AuditLogFilter();
  }
}

final auditLogFilterProvider =
    NotifierProvider<AuditLogFilterNotifier, AuditLogFilter>(
  AuditLogFilterNotifier.new,
);

/// Provider fetching audit trail logs with live filtering.
final auditLogsProvider =
    AutoDisposeFutureProvider<List<AttendanceLogModel>>((ref) async {
  final filter = ref.watch(auditLogFilterProvider);
  final repo = ref.watch(attendanceAdminRepositoryProvider);

  final logs = await repo.getAuditLogs(
    classId: filter.classId,
    date: filter.dateString,
  );

  if (filter.searchQuery.trim().isEmpty) {
    return logs;
  }

  final query = filter.searchQuery.trim().toLowerCase();
  return logs.where((log) {
    return log.studentName.toLowerCase().contains(query) ||
        log.rollNo.toLowerCase().contains(query) ||
        log.className.toLowerCase().contains(query) ||
        log.changedByName.toLowerCase().contains(query);
  }).toList();
});
