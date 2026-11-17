import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:slkc_app/features/sync/presentation/providers/sync_provider.dart';
import 'package:slkc_app/features/teachers/data/repositories/teacher_attendance_repository.dart';
import 'package:slkc_app/features/teachers/domain/models/teacher_attendance_model.dart';

/// Provides [TeacherAttendanceRepository]
final teacherAttendanceRepositoryProvider =
    Provider<TeacherAttendanceRepository>((ref) {
  final localDb = ref.watch(localDatabaseProvider);
  return TeacherAttendanceRepository(localDb: localDb);
});

/// Filter state for Teacher Attendance (date, session, search query)
class TeacherAttendanceFilter {
  final DateTime date;
  final String session;
  final String searchQuery;

  const TeacherAttendanceFilter({
    required this.date,
    required this.session,
    this.searchQuery = '',
  });

  String get dateString => DateFormat('yyyy-MM-dd').format(date);

  TeacherAttendanceFilter copyWith({
    DateTime? date,
    String? session,
    String? searchQuery,
  }) {
    return TeacherAttendanceFilter(
      date: date ?? this.date,
      session: session ?? this.session,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class TeacherAttendanceFilterNotifier
    extends StateNotifier<TeacherAttendanceFilter> {
  TeacherAttendanceFilterNotifier()
      : super(
          TeacherAttendanceFilter(
            date: DateTime.now(),
            session: _defaultSessionByTime(),
          ),
        );

  static String _defaultSessionByTime() {
    final now = DateTime.now();
    return now.hour >= 12
        ? AppConstants.sessionAfternoon
        : AppConstants.sessionMorning;
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void setSession(String session) {
    state = state.copyWith(session: session);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final teacherAttendanceFilterProvider = StateNotifierProvider<
    TeacherAttendanceFilterNotifier, TeacherAttendanceFilter>((ref) {
  return TeacherAttendanceFilterNotifier();
});

/// Notifier managing teacher attendance state for the selected date & session
class TeacherAttendanceNotifier
    extends StateNotifier<AsyncValue<List<TeacherAttendanceModel>>> {
  final Ref _ref;

  TeacherAttendanceNotifier(this._ref) : super(const AsyncLoading()) {
    loadAttendance();
  }

  TeacherAttendanceRepository get _repository =>
      _ref.read(teacherAttendanceRepositoryProvider);

  TeacherAttendanceFilter get _filter =>
      _ref.read(teacherAttendanceFilterProvider);

  Future<void> loadAttendance() async {
    state = const AsyncLoading();
    try {
      final records = await _repository.getTeacherAttendance(
        date: _filter.dateString,
        session: _filter.session,
      );
      state = AsyncData(records);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Toggles status between Present and Absent. If currently Unmarked, defaults to Present.
  Future<void> toggleStatus(TeacherAttendanceModel record) async {
    final currentList = state.value ?? [];
    final currentStatus = record.status;
    final newStatus = currentStatus == AppConstants.statusPresent
        ? AppConstants.statusAbsent
        : AppConstants.statusPresent;

    final adminProfile = _ref.read(authNotifierProvider).value;
    final adminId = adminProfile?.id ?? '';
    final adminName = adminProfile?.name ?? 'Admin';

    // 1. Optimistic UI update
    final updatedList = currentList.map((r) {
      if (r.teacherId == record.teacherId) {
        return r.copyWith(
          status: newStatus,
          markedBy: adminId,
          markedByName: adminName,
          updatedAt: DateTime.now(),
        );
      }
      return r;
    }).toList();
    state = AsyncData(updatedList);

    // 2. Persist
    try {
      await _repository.setTeacherAttendance(
        record: record,
        newStatus: newStatus,
        markedBy: adminId,
      );
    } catch (e) {
      // Revert on critical failure
      state = AsyncData(currentList);
      rethrow;
    }
  }

  /// Sets all teachers to [status] ('present' | 'absent')
  Future<void> markAll(String status) async {
    final currentList = state.value ?? [];
    if (currentList.isEmpty) return;

    final adminProfile = _ref.read(authNotifierProvider).value;
    final adminId = adminProfile?.id ?? '';
    final adminName = adminProfile?.name ?? 'Admin';

    // 1. Optimistic UI update
    final updatedList = currentList.map((r) {
      return r.copyWith(
        status: status,
        markedBy: adminId,
        markedByName: adminName,
        updatedAt: DateTime.now(),
      );
    }).toList();
    state = AsyncData(updatedList);

    // 2. Persist
    try {
      await _repository.markAllTeachers(
        records: currentList,
        status: status,
        markedBy: adminId,
      );
    } catch (e) {
      state = AsyncData(currentList);
      rethrow;
    }
  }
}

final teacherAttendanceProvider = StateNotifierProvider<
    TeacherAttendanceNotifier, AsyncValue<List<TeacherAttendanceModel>>>((ref) {
  // Reload whenever date or session changes
  ref.watch(teacherAttendanceFilterProvider.select((f) => '${f.dateString}_${f.session}'));
  return TeacherAttendanceNotifier(ref);
});
