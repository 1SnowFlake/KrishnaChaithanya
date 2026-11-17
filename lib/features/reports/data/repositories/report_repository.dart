import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/report_models.dart';

/// Repository responsible for aggregating attendance statistics, trends,
/// threshold alerts, and student performance metrics.
class ReportRepository {
  final SupabaseClient _supabase;

  ReportRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetches low attendance threshold from settings table (defaults to 75.0).
  Future<double> getLowAttendanceThreshold() async {
    try {
      final res = await _supabase
          .from('settings')
          .select('low_attendance_threshold')
          .maybeSingle();

      if (res != null && res['low_attendance_threshold'] != null) {
        return (res['low_attendance_threshold'] as num).toDouble();
      }
    } catch (_) {
      // Fallback default
    }
    return 75.0;
  }

  /// Aggregates attendance statistics across classes and date ranges.
  Future<AttendanceReportSummary> getAttendanceReport({
    required DateTime startDate,
    required DateTime endDate,
    String? classId,
    String? session,
  }) async {
    final threshold = await getLowAttendanceThreshold();

    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

    // 1. Fetch Class and Students Information
    String? className;
    final Map<String, String> classNamesMap = {};

    if (classId != null && classId.isNotEmpty) {
      final classRes = await _supabase
          .from('classes')
          .select('id, name')
          .eq('id', classId)
          .maybeSingle();
      if (classRes != null) {
        className = classRes['name'] as String;
        classNamesMap[classId] = className;
      }
    } else {
      final classesRes = await _supabase.from('classes').select('id, name');
      for (final c in (classesRes as List)) {
        classNamesMap[c['id'] as String] = c['name'] as String;
      }
    }

    // 2. Fetch Students
    PostgrestFilterBuilder studentsQuery = _supabase
        .from('students')
        .select('id, name, roll_no, class_id');

    if (classId != null && classId.isNotEmpty) {
      studentsQuery = studentsQuery.eq('class_id', classId);
    }

    final studentsData = await studentsQuery.order('roll_no', ascending: true);
    final List<Map<String, dynamic>> studentsList =
        List<Map<String, dynamic>>.from(studentsData as List);

    // 3. Fetch Attendance Records for the date range
    PostgrestFilterBuilder attendanceQuery = _supabase
        .from('attendance')
        .select('id, student_id, class_id, date, session, status')
        .gte('date', startDateStr)
        .lte('date', endDateStr);

    if (classId != null && classId.isNotEmpty) {
      attendanceQuery = attendanceQuery.eq('class_id', classId);
    }
    if (session != null && session.isNotEmpty && session != 'all') {
      attendanceQuery = attendanceQuery.eq('session', session);
    }

    final attendanceData = await attendanceQuery.order('date', ascending: true);
    final List<Map<String, dynamic>> attendanceRows =
        List<Map<String, dynamic>>.from(attendanceData as List);

    // 4. Group attendance by student
    final Map<String, List<Map<String, dynamic>>> recordsByStudent = {};
    for (final row in attendanceRows) {
      final sId = row['student_id'] as String;
      recordsByStudent.putIfAbsent(sId, () => []).add(row);
    }

    int totalPresentOverall = 0;
    int totalAbsentOverall = 0;

    final List<StudentAttendanceReport> studentReports = [];

    for (final s in studentsList) {
      final sId = s['id'] as String;
      final sName = s['name'] as String;
      final sRoll = s['roll_no']?.toString() ?? '-';
      final sClassId = s['class_id'] as String;
      final sClassName = classNamesMap[sClassId] ?? 'Class';

      final studentRecords = recordsByStudent[sId] ?? [];
      int present = 0;
      int absent = 0;

      for (final rec in studentRecords) {
        final status = rec['status'] as String;
        if (status == 'present') {
          present++;
        } else if (status == 'absent') {
          absent++;
        }
      }

      totalPresentOverall += present;
      totalAbsentOverall += absent;

      studentReports.add(
        StudentAttendanceReport(
          studentId: sId,
          studentName: sName,
          rollNo: sRoll,
          classId: sClassId,
          className: sClassName,
          totalSessions: present + absent,
          presentCount: present,
          absentCount: absent,
        ),
      );
    }

    // Sort students by roll number or name
    studentReports.sort((a, b) {
      final rollA = int.tryParse(a.rollNo);
      final rollB = int.tryParse(b.rollNo);
      if (rollA != null && rollB != null) {
        return rollA.compareTo(rollB);
      }
      return a.rollNo.compareTo(b.rollNo);
    });

    // 5. Aggregate Daily Trends
    final Map<String, List<Map<String, dynamic>>> recordsByDate = {};
    for (final row in attendanceRows) {
      final dateStr = row['date'] as String;
      recordsByDate.putIfAbsent(dateStr, () => []).add(row);
    }

    final sortedDates = recordsByDate.keys.toList()..sort();
    final List<DailyAttendanceTrend> dailyTrends = [];

    for (final dateStr in sortedDates) {
      final rows = recordsByDate[dateStr]!;
      int dayPresent = 0;
      int dayAbsent = 0;

      for (final r in rows) {
        final status = r['status'] as String;
        if (status == 'present') {
          dayPresent++;
        } else if (status == 'absent') {
          dayAbsent++;
        }
      }

      dailyTrends.add(
        DailyAttendanceTrend(
          date: DateTime.parse(dateStr),
          presentCount: dayPresent,
          absentCount: dayAbsent,
        ),
      );
    }

    return AttendanceReportSummary(
      startDate: startDate,
      endDate: endDate,
      classId: classId,
      className: className,
      session: session,
      threshold: threshold,
      totalStudents: studentReports.length,
      totalSessions: totalPresentOverall + totalAbsentOverall,
      totalPresent: totalPresentOverall,
      totalAbsent: totalAbsentOverall,
      students: studentReports,
      dailyTrends: dailyTrends,
    );
  }
}
