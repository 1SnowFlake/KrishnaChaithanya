import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/sync/data/local/app_local_database.dart';
import 'package:slkc_app/features/teachers/domain/models/teacher_attendance_model.dart';

/// Repository responsible for Teacher Attendance CRUD and synchronisation.
/// Uses Supabase `teacher_attendance` when reachable and mirrors all records
/// to local SQLite for offline stability and instant UI updates.
class TeacherAttendanceRepository {
  final SupabaseClient _supabase;
  final AppLocalDatabase _localDb;
  final Uuid _uuid;

  TeacherAttendanceRepository({
    SupabaseClient? supabaseClient,
    required AppLocalDatabase localDb,
    Uuid? uuid,
  })  : _supabase = supabaseClient ?? SupabaseConfig.client,
        _localDb = localDb,
        _uuid = uuid ?? const Uuid();

  /// Fetches all active teachers and combines them with existing attendance
  /// records for the specified [date] (YYYY-MM-DD) and [session] ('morning' | 'afternoon').
  Future<List<TeacherAttendanceModel>> getTeacherAttendance({
    required String date,
    required String session,
  }) async {
    // 1. Fetch active teachers from profiles
    final teachersResponse = await _supabase
        .from(AppConstants.tableProfiles)
        .select('id, name, email, role')
        .eq('is_active', true)
        .order('name', ascending: true);

    final teachersList = (teachersResponse as List).cast<Map<String, dynamic>>();

    if (teachersList.isEmpty) {
      return [];
    }

    // 2. Fetch existing attendance records from Supabase (or fallback to local DB)
    final attendanceMap = <String, Map<String, dynamic>>{};

    try {
      final remoteRecords = await _supabase
          .from('teacher_attendance')
          .select('id, teacher_id, status, marked_by, updated_at, profiles:marked_by(name)')
          .eq('date', date)
          .eq('session', session);

      for (final row in (remoteRecords as List).cast<Map<String, dynamic>>()) {
        final teacherId = row['teacher_id'] as String;
        attendanceMap[teacherId] = row;

        // Cache into local DB
        _localDb.upsertTeacherAttendance(
          id: row['id'] as String? ?? _uuid.v4(),
          teacherId: teacherId,
          date: date,
          session: session,
          status: row['status'] as String,
          markedBy: row['marked_by'] as String? ?? '',
          updatedAt: row['updated_at'] as String? ?? DateTime.now().toUtc().toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('Supabase teacher_attendance query fallback to local DB: $e');
      // Fallback: Read from local DB
      final localRecords = _localDb.getTeacherAttendance(date: date, session: session);
      for (final row in localRecords) {
        final teacherId = row['teacher_id'] as String;
        attendanceMap[teacherId] = row;
      }
    }

    // 3. Merge teachers and attendance into TeacherAttendanceModel list
    return teachersList.map((t) {
      final teacherId = t['id'] as String;
      final teacherName = t['name'] as String;
      final teacherEmail = t['email'] as String? ?? '';
      final role = t['role'] as String? ?? 'teacher';

      final existing = attendanceMap[teacherId];
      final profile = existing?['profiles'] as Map<String, dynamic>?;

      return TeacherAttendanceModel(
        teacherId: teacherId,
        teacherName: teacherName,
        teacherEmail: teacherEmail,
        role: role,
        date: date,
        session: session,
        attendanceId: existing?['id'] as String?,
        status: existing?['status'] as String?,
        markedBy: existing?['marked_by'] as String?,
        markedByName: profile?['name'] as String?,
        updatedAt: existing?['updated_at'] != null
            ? DateTime.tryParse(existing!['updated_at'] as String)?.toLocal()
            : null,
      );
    }).toList();
  }

  /// Sets or updates a single teacher's attendance status.
  Future<void> setTeacherAttendance({
    required TeacherAttendanceModel record,
    required String newStatus,
    required String markedBy,
  }) async {
    final nowStr = DateTime.now().toUtc().toIso8601String();
    final recId = record.attendanceId ?? _uuid.v4();

    // 1. Immediately write to local DB for snappy optimistic UI
    _localDb.upsertTeacherAttendance(
      id: recId,
      teacherId: record.teacherId,
      date: record.date,
      session: record.session,
      status: newStatus,
      markedBy: markedBy,
      updatedAt: nowStr,
    );

    // 2. Try remote Supabase upsert
    try {
      await _supabase.from('teacher_attendance').upsert({
        'id': recId,
        'teacher_id': record.teacherId,
        'date': record.date,
        'session': record.session,
        'status': newStatus,
        'marked_by': markedBy,
        'updated_at': nowStr,
      }, onConflict: 'teacher_id,date,session');
    } catch (e) {
      debugPrint('Failed to sync teacher attendance to remote: $e');
    }
  }

  /// Batch marks all teachers in the given list as [status] ('present' or 'absent').
  Future<void> markAllTeachers({
    required List<TeacherAttendanceModel> records,
    required String status,
    required String markedBy,
  }) async {
    final nowStr = DateTime.now().toUtc().toIso8601String();
    final upsertPayload = <Map<String, dynamic>>[];

    for (final r in records) {
      final recId = r.attendanceId ?? _uuid.v4();
      _localDb.upsertTeacherAttendance(
        id: recId,
        teacherId: r.teacherId,
        date: r.date,
        session: r.session,
        status: status,
        markedBy: markedBy,
        updatedAt: nowStr,
      );

      upsertPayload.add({
        'id': recId,
        'teacher_id': r.teacherId,
        'date': r.date,
        'session': r.session,
        'status': status,
        'marked_by': markedBy,
        'updated_at': nowStr,
      });
    }

    try {
      await _supabase
          .from('teacher_attendance')
          .upsert(upsertPayload, onConflict: 'teacher_id,date,session');
    } catch (e) {
      debugPrint('Failed to batch sync teacher attendance: $e');
    }
  }
}
