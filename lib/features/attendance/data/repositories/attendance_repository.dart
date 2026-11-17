import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/attendance/domain/models/class_session_status.dart';
import 'package:slkc_app/features/classes/domain/models/class_model.dart';
import 'package:slkc_app/features/students/domain/models/student_model.dart';
import 'package:slkc_app/features/sync/data/local/app_local_database.dart';
import 'package:slkc_app/features/sync/domain/models/outbox_item_model.dart';

/// Repository handling attendance taking, session verification,
/// holiday/weekly off detection, cutoff checks, and offline SQLite caching.
class AttendanceRepository {
  final SupabaseClient _supabase;
  final AppLocalDatabase? _localDb;
  final Uuid _uuid = const Uuid();

  AttendanceRepository(this._supabase, [this._localDb]);

  /// Returns today's date formatted as YYYY-MM-DD in the school's configured timezone.
  Future<String> getSchoolTodayString() async {
    try {
      final res = await _supabase.rpc('school_today');
      if (res != null) return res.toString().split('T')[0];
    } catch (_) {}
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// Fetches classes assigned to the logged-in teacher (both primary and active substitute).
  /// Enforced automatically by RLS policy `teacher_read_assigned_classes`.
  Future<List<ClassModel>> getTeacherAssignedClasses() async {
    try {
      final response = await _supabase
          .from(AppConstants.tableClasses)
          .select('''
            id,
            name,
            primary_teacher_id,
            created_at,
            profiles:primary_teacher_id ( name ),
            students ( id )
          ''')
          .order('name', ascending: true);

      final list = (response as List)
          .map((row) => ClassModel.fromMap(row as Map<String, dynamic>))
          .toList();

      // Cache classes in local SQLite
      final localDb = _localDb;
      if (localDb != null) {
        localDb.cacheClasses(
          list
              .map((c) => {
                    'id': c.id,
                    'name': c.name,
                    'primary_teacher_id': c.primaryTeacherId,
                  })
              .toList(),
        );
      }

      return list;
    } catch (_) {
      // Fallback to local SQLite cache when offline
      final localDb = _localDb;
      if (localDb != null) {
        final cached = localDb.getCachedClasses();
        if (cached.isNotEmpty) {
          return cached
              .map((m) => ClassModel(
                    id: m['id'] as String,
                    name: m['name'] as String,
                    primaryTeacherId: m['primary_teacher_id'] as String?,
                    createdAt: DateTime.now(),
                  ))
              .toList();
        }
      }
      rethrow;
    }
  }

  /// Checks if a teacher is currently a substitute for a given class.
  Future<bool> isTeacherSubstitute(String classId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final today = await getSchoolTodayString();
    final response = await _supabase
        .from(AppConstants.tableSubstitutes)
        .select('id')
        .eq('class_id', classId)
        .eq('teacher_id', user.id)
        .lte('start_date', today)
        .gte('end_date', today)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  /// Checks whether today is a holiday or weekly off day.
  Future<({bool isClosed, String? reason})> checkSchoolClosureToday() async {
    final today = await getSchoolTodayString();

    // 1. Check holidays table
    final holidayRes = await _supabase
        .from(AppConstants.tableHolidays)
        .select('name')
        .lte('start_date', today)
        .gte('end_date', today)
        .maybeSingle();

    if (holidayRes != null) {
      return (
        isClosed: true,
        reason: 'Holiday: ${holidayRes['name'] ?? 'School Closed'}'
      );
    }

    // 2. Check weekly off days in settings
    try {
      final settings = await _supabase
          .from(AppConstants.tableSettings)
          .select('weekly_off_days')
          .maybeSingle();

      if (settings != null && settings['weekly_off_days'] is List) {
        final offDays = (settings['weekly_off_days'] as List).cast<int>();
        final dow = DateTime.parse(today).weekday % 7; // Postgres DOW: 0 = Sun
        if (offDays.contains(dow)) {
          return (
            isClosed: true,
            reason: 'Weekly Off: Attendance is closed on non-working days.'
          );
        }
      }
    } catch (_) {}

    return (isClosed: false, reason: null);
  }

  /// Fetches the submission status and cutoffs for both sessions today for a class.
  Future<ClassSessionStatus> getClassSessionStatusToday(String classId) async {
    final today = await getSchoolTodayString();
    final closure = await checkSchoolClosureToday();

    // Fetch cutoff times from settings
    bool morningCutoffPassed = false;
    bool afternoonCutoffPassed = false;
    try {
      final settings = await _supabase
          .from(AppConstants.tableSettings)
          .select('morning_cutoff, afternoon_cutoff, timezone')
          .maybeSingle();

      if (settings != null) {
        final now = DateTime.now();
        final mCutoffStr = settings['morning_cutoff'] as String? ?? '10:30:00';
        final aCutoffStr = settings['afternoon_cutoff'] as String? ?? '14:30:00';

        final mParts = mCutoffStr.split(':').map(int.parse).toList();
        final aParts = aCutoffStr.split(':').map(int.parse).toList();

        final mTime = DateTime(now.year, now.month, now.day, mParts[0], mParts[1]);
        final aTime = DateTime(now.year, now.month, now.day, aParts[0], aParts[1]);

        morningCutoffPassed = now.isAfter(mTime);
        afternoonCutoffPassed = now.isAfter(aTime);
      }
    } catch (_) {}

    // Query today's attendance records for this class
    final response = await _supabase
        .from(AppConstants.tableAttendance)
        .select('session, status')
        .eq('class_id', classId)
        .eq('date', today);

    final records = response as List;

    int mPresent = 0;
    int mAbsent = 0;
    int aPresent = 0;
    int aAbsent = 0;

    for (final r in records) {
      final sess = r['session'] as String;
      final st = r['status'] as String;
      if (sess == AppConstants.sessionMorning) {
        if (st == AppConstants.statusPresent) mPresent++;
        if (st == AppConstants.statusAbsent) mAbsent++;
      } else if (sess == AppConstants.sessionAfternoon) {
        if (st == AppConstants.statusPresent) aPresent++;
        if (st == AppConstants.statusAbsent) aAbsent++;
      }
    }

    return ClassSessionStatus(
      classId: classId,
      isHoliday: closure.isClosed && (closure.reason?.contains('Holiday') ?? false),
      holidayName: closure.reason,
      isWeeklyOff: closure.isClosed && !(closure.reason?.contains('Holiday') ?? false),
      morningSubmitted: (mPresent + mAbsent) > 0,
      morningPresent: mPresent,
      morningAbsent: mAbsent,
      afternoonSubmitted: (aPresent + aAbsent) > 0,
      afternoonPresent: aPresent,
      afternoonAbsent: aAbsent,
      morningCutoffPassed: morningCutoffPassed,
      afternoonCutoffPassed: afternoonCutoffPassed,
    );
  }

  /// Fetches all active students in a class, sorted naturally by roll number.
  /// Falls back to local SQLite cache if device is offline.
  Future<List<StudentModel>> getStudentsInClass(String classId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableStudents)
          .select()
          .eq('class_id', classId)
          .eq('is_active', true)
          .order('roll_no', ascending: true);

      final list = (response as List)
          .map((r) => StudentModel.fromMap(r as Map<String, dynamic>))
          .toList();

      // Cache students locally
      final localDb = _localDb;
      if (localDb != null) {
        localDb.cacheStudents(
          list
              .map((s) => {
                    'id': s.id,
                    'name': s.name,
                    'roll_no': s.rollNo,
                    'class_id': s.classId,
                  })
              .toList(),
        );
      }

      _sortStudents(list);
      return list;
    } catch (_) {
      // Fallback to local SQLite cache
      final localDb = _localDb;
      if (localDb != null) {
        final cached = localDb.getCachedStudents(classId);
        if (cached.isNotEmpty) {
          final list = cached
              .map((m) => StudentModel(
                    id: m['id'] as String,
                    name: m['name'] as String,
                    rollNo: m['roll_no']?.toString() ?? '',
                    classId: m['class_id'] as String,
                    isActive: true,
                    createdAt: DateTime.now(),
                  ))
              .toList();
          _sortStudents(list);
          return list;
        }
      }
      rethrow;
    }
  }

  void _sortStudents(List<StudentModel> list) {
    list.sort((a, b) {
      final aNum = int.tryParse(a.rollNo);
      final bNum = int.tryParse(b.rollNo);
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      return a.rollNo.compareTo(b.rollNo);
    });
  }

  /// Fetches existing attendance records for a class on today's session (for editing).
  Future<Map<String, String>> getTodayAttendanceDraft(
    String classId,
    String session,
  ) async {
    final today = await getSchoolTodayString();
    try {
      final response = await _supabase
          .from(AppConstants.tableAttendance)
          .select('student_id, status')
          .eq('class_id', classId)
          .eq('date', today)
          .eq('session', session);

      final map = <String, String>{};
      for (final row in (response as List)) {
        map[row['student_id'] as String] = row['status'] as String;
      }
      return map;
    } catch (_) {
      // Offline fallback: check local cached attendance
      final localDb = _localDb;
      if (localDb != null) {
        final cached = localDb.getCachedAttendance(
          classId: classId,
          date: today,
          session: session,
        );
        final map = <String, String>{};
        for (final row in cached) {
          map[row['student_id'] as String] = row['status'] as String;
        }
        return map;
      }
      return {};
    }
  }

  /// Submits or updates attendance records.
  /// 1. Always queues locally in SQLite Outbox for offline durability.
  /// 2. If online, attempts idempotent upsert to Supabase.
  Future<void> submitAttendance({
    required String classId,
    required String session,
    required Map<String, String> studentStatusMap, // studentId -> 'present' | 'absent'
    required bool isSubstitute,
  }) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'local_teacher';
    final today = await getSchoolTodayString();

    // 1. Queue in local SQLite Outbox first (guarantees offline persistence)
    final localDb = _localDb;
    if (localDb != null) {
      final outboxItems = studentStatusMap.entries.map((entry) {
        return OutboxItemModel(
          id: _uuid.v4(),
          studentId: entry.key,
          classId: classId,
          date: today,
          session: session,
          status: entry.value,
          markedBy: userId,
          isSubstitute: isSubstitute,
          createdAt: DateTime.now(),
          syncStatus: 'pending',
        );
      }).toList();

      localDb.queueBatchAttendance(outboxItems);
      localDb.cacheAttendance(
        studentStatusMap.entries.map((entry) {
          return {
            'id': _uuid.v4(),
            'student_id': entry.key,
            'class_id': classId,
            'date': today,
            'session': session,
            'status': entry.value,
            'marked_by': userId,
            'is_substitute': isSubstitute,
          };
        }).toList(),
      );
    }

    // 2. Attempt online upsert to Supabase
    try {
      if (user != null) {
        final rows = studentStatusMap.entries.map((entry) {
          return {
            'student_id': entry.key,
            'class_id': classId,
            'date': today,
            'session': session,
            'status': entry.value,
            'marked_by': user.id,
            'is_substitute': isSubstitute,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
        }).toList();

        await _supabase.from(AppConstants.tableAttendance).upsert(
              rows,
              onConflict: 'student_id,date,session',
            );

        // Mark items as synced in local DB
        if (localDb != null) {
          localDb.clearSyncedOutbox();
        }
      }
    } catch (e) {
      // If network fails, attendance is preserved in the local Outbox
      // and will sync automatically when connection resumes.
      if (localDb == null) {
        rethrow;
      }
    }
  }
}
