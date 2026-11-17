import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/attendance/data/repositories/attendance_repository.dart';
import 'package:slkc_app/features/attendance/domain/models/class_session_status.dart';
import 'package:slkc_app/features/classes/domain/models/class_model.dart';
import 'package:slkc_app/features/students/domain/models/student_model.dart';
import 'package:slkc_app/features/sync/presentation/providers/sync_provider.dart';

/// Provides the singleton [AttendanceRepository].
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final localDb = ref.watch(localDatabaseProvider);
  return AttendanceRepository(SupabaseConfig.client, localDb);
});

/// Future provider checking if today is a holiday or weekly off day.
final schoolClosureProvider =
    FutureProvider<({bool isClosed, String? reason})>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.checkSchoolClosureToday();
});

/// Fetches classes assigned to the active teacher (primary or substitute).
final teacherClassesProvider = FutureProvider<List<ClassModel>>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getTeacherAssignedClasses();
});

/// Checks whether morning and afternoon attendance have been submitted today for [classId].
final classSessionStatusProvider =
    FutureProvider.family<ClassSessionStatus, String>((ref, classId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return await repo.getClassSessionStatusToday(classId);
});

/// Holds the in-progress draft attendance state when a teacher takes/edits attendance.
class AttendanceDraftState {
  final List<StudentModel> students;
  final Map<String, String> statuses; // studentId -> 'present' | 'absent'
  final bool isSubstitute;
  final bool isSubmitting;

  const AttendanceDraftState({
    this.students = const [],
    this.statuses = const {},
    this.isSubstitute = false,
    this.isSubmitting = false,
  });

  int get presentCount =>
      statuses.values.where((s) => s == AppConstants.statusPresent).length;

  int get absentCount =>
      statuses.values.where((s) => s == AppConstants.statusAbsent).length;

  List<StudentModel> get absentStudents =>
      students.where((s) => statuses[s.id] == AppConstants.statusAbsent).toList();

  AttendanceDraftState copyWith({
    List<StudentModel>? students,
    Map<String, String>? statuses,
    bool? isSubstitute,
    bool? isSubmitting,
  }) {
    return AttendanceDraftState(
      students: students ?? this.students,
      statuses: statuses ?? this.statuses,
      isSubstitute: isSubstitute ?? this.isSubstitute,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// Parameters required to initialize the attendance draft notifier.
class AttendanceParams {
  final String classId;
  final String session;

  const AttendanceParams({required this.classId, required this.session});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceParams &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          session == other.session;

  @override
  int get hashCode => classId.hashCode ^ session.hashCode;
}

/// Family notifier managing attendance taking for a specific class and session.
class AttendanceDraftNotifier
    extends FamilyAsyncNotifier<AttendanceDraftState, AttendanceParams> {
  late final AttendanceRepository _repo;

  @override
  FutureOr<AttendanceDraftState> build(AttendanceParams arg) async {
    _repo = ref.watch(attendanceRepositoryProvider);

    // 1. Fetch students enrolled in this class
    final students = await _repo.getStudentsInClass(arg.classId);

    // 2. Fetch existing records for today (if already submitted, loads them for edit)
    final existingDraft =
        await _repo.getTodayAttendanceDraft(arg.classId, arg.session);

    // 3. Determine if current teacher is acting as a substitute
    final isSub = await _repo.isTeacherSubstitute(arg.classId);

    final statuses = <String, String>{};
    for (final s in students) {
      if (existingDraft.containsKey(s.id)) {
        statuses[s.id] = existingDraft[s.id]!;
      } else {
        // Default to present for rapid marking
        statuses[s.id] = AppConstants.statusPresent;
      }
    }

    return AttendanceDraftState(
      students: students,
      statuses: statuses,
      isSubstitute: isSub,
    );
  }

  /// Toggles an individual student's status between 'present' and 'absent'.
  void toggleStudent(String studentId) {
    final current = state.value;
    if (current == null) return;

    final updated = Map<String, String>.from(current.statuses);
    final prev = updated[studentId] ?? AppConstants.statusPresent;
    updated[studentId] = (prev == AppConstants.statusPresent)
        ? AppConstants.statusAbsent
        : AppConstants.statusPresent;

    state = AsyncData(current.copyWith(statuses: updated));
  }

  /// Marks every student as 'present'.
  void markAllPresent() {
    final current = state.value;
    if (current == null) return;

    final updated = <String, String>{};
    for (final s in current.students) {
      updated[s.id] = AppConstants.statusPresent;
    }
    state = AsyncData(current.copyWith(statuses: updated));
  }

  /// Marks every student as 'absent'.
  void markAllAbsent() {
    final current = state.value;
    if (current == null) return;

    final updated = <String, String>{};
    for (final s in current.students) {
      updated[s.id] = AppConstants.statusAbsent;
    }
    state = AsyncData(current.copyWith(statuses: updated));
  }

  /// Submits the final attendance map to Supabase.
  Future<void> submit() async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isSubmitting: true));

    try {
      await _repo.submitAttendance(
        classId: arg.classId,
        session: arg.session,
        studentStatusMap: current.statuses,
        isSubstitute: current.isSubstitute,
      );

      // Invalidate session status so home dashboard chips update immediately
      ref.invalidate(classSessionStatusProvider(arg.classId));
    } finally {
      state = AsyncData(current.copyWith(isSubmitting: false));
    }
  }
}

final attendanceDraftNotifierProvider = AsyncNotifierProvider.family<
    AttendanceDraftNotifier, AttendanceDraftState, AttendanceParams>(
  AttendanceDraftNotifier.new,
);
