import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/report_models.dart';

/// Service responsible for generating and sharing CSV exports of attendance reports.
class CsvExportService {
  /// Generates the raw CSV string from an [AttendanceReportSummary].
  static String generateCsv(AttendanceReportSummary summary) {
    final rows = <List<dynamic>>[];

    // Header Metadata
    rows.add(['SCHOOL ATTENDANCE REPORT']);
    rows.add(['Generated At', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())]);
    rows.add(['Target Class', summary.className ?? 'All Classes']);
    rows.add([
      'Date Range',
      '${DateFormat('yyyy-MM-dd').format(summary.startDate)} to ${DateFormat('yyyy-MM-dd').format(summary.endDate)}'
    ]);
    rows.add(['Session Filter', (summary.session ?? 'All Sessions').toUpperCase()]);
    rows.add(['Low Attendance Threshold', '${summary.threshold.toStringAsFixed(1)}%']);
    rows.add(['Overall Attendance Rate', '${summary.overallPercentage.toStringAsFixed(1)}%']);
    rows.add(['Total Student Records', summary.students.length]);
    rows.add(['Students Below Threshold', summary.lowAttendanceCount]);
    rows.add([]); // Blank line separator

    // Column Headers
    rows.add([
      'Roll No',
      'Student Name',
      'Class',
      'Total Sessions',
      'Present',
      'Absent',
      'Attendance %',
      'Threshold Status',
    ]);

    // Data Rows
    for (final s in summary.students) {
      final isLow = s.isLowAttendance(summary.threshold);
      rows.add([
        s.rollNo,
        s.studentName,
        s.className,
        s.totalSessions,
        s.presentCount,
        s.absentCount,
        '${s.attendancePercentage.toStringAsFixed(1)}%',
        isLow ? 'BELOW THRESHOLD (<${summary.threshold.toStringAsFixed(0)}%)' : 'NORMAL',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Exports and triggers the system share/save sheet for the generated CSV file.
  static Future<void> exportAndShareCsv(AttendanceReportSummary summary) async {
    final csvContent = generateCsv(summary);
    final fileName =
        'attendance_report_${DateFormat('yyyyMMdd').format(summary.startDate)}_${DateFormat('yyyyMMdd').format(summary.endDate)}.csv';

    final bytes = utf8.encode(csvContent);
    final xFile = XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: fileName,
    );

    await Share.shareXFiles(
      [xFile],
      subject: 'School Attendance Report (${summary.className ?? "All Classes"})',
      text: 'Attached is the School Attendance Report for ${summary.className ?? "All Classes"}.',
    );
  }
}
