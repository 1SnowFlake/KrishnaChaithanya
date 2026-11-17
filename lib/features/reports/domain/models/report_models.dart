import 'package:intl/intl.dart';

/// Individual student's attendance summary for a reporting period.
class StudentAttendanceReport {
  final String studentId;
  final String studentName;
  final String rollNo;
  final String classId;
  final String className;
  final int totalSessions;
  final int presentCount;
  final int absentCount;

  const StudentAttendanceReport({
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.classId,
    required this.className,
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
  });

  /// Attendance rate in percentage (0.0 to 100.0).
  double get attendancePercentage {
    if (totalSessions == 0) return 100.0; // Default when no sessions took place
    return (presentCount / totalSessions) * 100.0;
  }

  /// Whether student attendance falls strictly below the school threshold.
  bool isLowAttendance(double threshold) {
    if (totalSessions == 0) return false;
    return attendancePercentage < threshold;
  }
}

/// Aggregated attendance trend for a specific calendar day.
class DailyAttendanceTrend {
  final DateTime date;
  final int presentCount;
  final int absentCount;

  const DailyAttendanceTrend({
    required this.date,
    required this.presentCount,
    required this.absentCount,
  });

  int get total => presentCount + absentCount;

  double get attendancePercentage {
    if (total == 0) return 0.0;
    return (presentCount / total) * 100.0;
  }

  String get formattedDate => DateFormat('MMM dd').format(date);
  String get isoDate => DateFormat('yyyy-MM-dd').format(date);
}

/// Complete aggregated attendance report summary across classes and date ranges.
class AttendanceReportSummary {
  final DateTime startDate;
  final DateTime endDate;
  final String? classId;
  final String? className;
  final String? session;
  final double threshold;
  final int totalStudents;
  final int totalSessions;
  final int totalPresent;
  final int totalAbsent;
  final List<StudentAttendanceReport> students;
  final List<DailyAttendanceTrend> dailyTrends;

  const AttendanceReportSummary({
    required this.startDate,
    required this.endDate,
    this.classId,
    this.className,
    this.session,
    required this.threshold,
    required this.totalStudents,
    required this.totalSessions,
    required this.totalPresent,
    required this.totalAbsent,
    required this.students,
    required this.dailyTrends,
  });

  /// Overall attendance percentage across all student sessions.
  double get overallPercentage {
    final total = totalPresent + totalAbsent;
    if (total == 0) return 0.0;
    return (totalPresent / total) * 100.0;
  }

  /// Total count of students whose attendance rate is strictly below threshold.
  int get lowAttendanceCount =>
      students.where((s) => s.isLowAttendance(threshold)).length;

  /// Students filtered by low attendance status.
  List<StudentAttendanceReport> get lowAttendanceStudents =>
      students.where((s) => s.isLowAttendance(threshold)).toList();
}
