import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/attendance/domain/models/attendance_admin_record.dart';
import 'package:slkc_app/features/attendance/domain/models/attendance_log_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Repository handling Admin-level attendance overrides and audit trail logs.
class AttendanceAdminRepository {
  final SupabaseClient _supabase;
  final Uuid _uuid;

  AttendanceAdminRepository({
    SupabaseClient? supabaseClient,
    Uuid? uuid,
  })  : _supabase = supabaseClient ?? SupabaseConfig.client,
        _uuid = uuid ?? const Uuid();

  /// Fetches all active students in [classId] combined with any existing
  /// attendance records for the given [date] (YYYY-MM-DD) and [session].
  Future<List<AttendanceAdminRecord>> getClassAttendance({
    required String classId,
    required String date,
    required String session,
  }) async {
    // 1. Fetch active students in this class
    final studentsResponse = await _supabase
        .from(AppConstants.tableStudents)
        .select('id, name, roll_no')
        .eq('class_id', classId)
        .eq('is_active', true)
        .order('roll_no', ascending: true);

    final studentsList = (studentsResponse as List).cast<Map<String, dynamic>>();

    if (studentsList.isEmpty) {
      return [];
    }

    // 2. Fetch existing attendance records for (classId, date, session)
    final attendanceResponse = await _supabase
        .from(AppConstants.tableAttendance)
        .select('id, student_id, status, marked_by, updated_at, profiles:marked_by(name)')
        .eq('class_id', classId)
        .eq('date', date)
        .eq('session', session);

    final attendanceList = (attendanceResponse as List).cast<Map<String, dynamic>>();

    // Index attendance by student_id
    final attendanceMap = <String, Map<String, dynamic>>{};
    for (final row in attendanceList) {
      final studentId = row['student_id'] as String;
      attendanceMap[studentId] = row;
    }

    // 3. Merge students and attendance into admin records
    return studentsList.map((st) {
      final studentId = st['id'] as String;
      final studentName = st['name'] as String;
      final rollNo = st['roll_no'] as String;

      final existing = attendanceMap[studentId];
      final profile = existing?['profiles'] as Map<String, dynamic>?;

      return AttendanceAdminRecord(
        studentId: studentId,
        studentName: studentName,
        rollNo: rollNo,
        classId: classId,
        date: date,
        session: session,
        attendanceId: existing?['id'] as String?,
        status: existing?['status'] as String?,
        markedBy: existing?['marked_by'] as String?,
        markedByName: profile?['name'] as String?,
        updatedAt: existing?['updated_at'] != null
            ? DateTime.parse(existing!['updated_at'] as String).toLocal()
            : null,
      );
    }).toList();
  }

  /// Updates or inserts a single student's attendance record as Admin.
  /// Automatically fires the database audit trigger `trg_attendance_audit`.
  Future<void> saveStudentAttendance({
    required AttendanceAdminRecord record,
    required String newStatus,
    required String adminId,
  }) async {
    final nowStr = DateTime.now().toUtc().toIso8601String();

    if (record.attendanceId != null) {
      // Record already exists; update it
      await _supabase
          .from(AppConstants.tableAttendance)
          .update({
            'status': newStatus,
            'marked_by': adminId,
            'updated_at': nowStr,
          })
          .eq('id', record.attendanceId!);
    } else {
      // Record does not exist yet; insert a new one
      final newId = _uuid.v4();
      await _supabase.from(AppConstants.tableAttendance).insert({
        'id': newId,
        'student_id': record.studentId,
        'class_id': record.classId,
        'date': record.date,
        'session': record.session,
        'status': newStatus,
        'marked_by': adminId,
        'is_substitute': false,
        'created_at': nowStr,
        'updated_at': nowStr,
      });
    }
  }

  /// Batch mark all students in class as either [AppConstants.statusPresent] or [AppConstants.statusAbsent].
  Future<void> batchSetClassAttendance({
    required List<AttendanceAdminRecord> records,
    required String newStatus,
    required String adminId,
  }) async {
    if (records.isEmpty) return;

    final nowStr = DateTime.now().toUtc().toIso8601String();

    final upsertPayload = records.map((record) {
      final map = <String, dynamic>{
        'student_id': record.studentId,
        'class_id': record.classId,
        'date': record.date,
        'session': record.session,
        'status': newStatus,
        'marked_by': adminId,
        'is_substitute': false,
        'updated_at': nowStr,
      };
      if (record.attendanceId != null) {
        map['id'] = record.attendanceId;
      }
      return map;
    }).toList();

    await _supabase
        .from(AppConstants.tableAttendance)
        .upsert(upsertPayload, onConflict: 'student_id,date,session');
  }

  /// Fetches the live audit trail from `attendance_log`.
  /// Admin policy permits reading all records.
  Future<List<AttendanceLogModel>> getAuditLogs({
    String? classId,
    String? date,
    int limit = 100,
  }) async {
    var query = _supabase.from(AppConstants.tableAttendanceLog).select(
      'id, attendance_id, old_status, new_status, changed_by, changed_at, '
      'profiles:changed_by(name, email, role), '
      'attendance:attendance_id(date, session, class_id, students:student_id(name, roll_no), classes:class_id(name))',
    );

    if (date != null && date.isNotEmpty) {
      query = query.eq('attendance.date', date);
    }

    if (classId != null && classId.isNotEmpty) {
      query = query.eq('attendance.class_id', classId);
    }

    final response = await query.order('changed_at', ascending: false).limit(limit);

    final rawList = (response as List).cast<Map<String, dynamic>>();
    return rawList.map((row) => AttendanceLogModel.fromJson(row)).toList();
  }
}
