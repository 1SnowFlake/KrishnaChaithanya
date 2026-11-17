import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/features/reports/data/repositories/report_repository.dart';
import 'package:slkc_app/features/reports/data/services/csv_export_service.dart';
import 'package:slkc_app/features/reports/data/services/pdf_export_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const supabaseUrl = 'https://cnwcambhldsmvpuwgcqj.supabase.co';
  const supabaseAnonKey = 'sb_publishable_IlAsVPCWoKdFl-Xc5RxaYA_SvftODPl';

  test('Phase 9 E2E: Reports, Analytics, Low Attendance Thresholds, CSV & PDF Export', () async {
    print('\n==========================================');
    print('STEP 1: Initializing Supabase client...');
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

    // ── 1. Sign in as Admin ───────────────────────────────────────────
    print('\n==========================================');
    print('STEP 2: Signing in as admin@school.com...');
    final adminAuth = await client.auth.signInWithPassword(
      email: 'admin@school.com',
      password: 'Test@123',
    );
    expect(adminAuth.user, isNotNull);
    final adminId = adminAuth.user!.id;
    print('Logged in as Admin: $adminId');

    final reportRepo = ReportRepository(supabase: client);

    // ── 2. Fetch Classes and Students ─────────────────────────────────
    print('\n==========================================');
    print('STEP 3: Finding class with student roster...');
    final classes = await client.from('classes').select('id, name').order('name');
    expect(classes, isNotEmpty);

    Map<String, dynamic>? testClass;
    List<dynamic> students = [];

    for (final c in classes) {
      final sList = await client
          .from('students')
          .select('id, name, roll_no')
          .eq('class_id', c['id'])
          .order('roll_no');
      if (sList.length >= 2) {
        testClass = c;
        students = sList;
        break;
      }
    }

    expect(testClass, isNotNull, reason: 'Found class with at least 2 students');
    final testClassId = testClass!['id'] as String;
    final testClassName = testClass['name'] as String;
    print('Target Class: $testClassName ($testClassId)');

    final student1 = students[0];
    final student2 = students[1];
    print('Student 1: ${student1['name']} (Roll: ${student1['roll_no']})');
    print('Student 2: ${student2['name']} (Roll: ${student2['roll_no']})');

    // ── 3. Seed Known Attendance for Exact Math Testing ───────────────
    print('\n==========================================');
    print('STEP 4: Seeding test attendance for 2 sessions (Day 1 & Day 2)...');
    final now = DateTime.now();
    final day1 = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2));
    final day2 = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final day1Str = DateFormat('yyyy-MM-dd').format(day1);
    final day2Str = DateFormat('yyyy-MM-dd').format(day2);

    // Clean up any prior test records for these dates to ensure clean state
    await client
        .from('attendance')
        .delete()
        .eq('class_id', testClassId)
        .inFilter('date', [day1Str, day2Str]);

    // Student 1: Present both days (100%)
    // Student 2: Present Day 1, Absent Day 2 (50% -> below 75% threshold!)
    await client.from('attendance').insert([
      {
        'student_id': student1['id'],
        'class_id': testClassId,
        'date': day1Str,
        'session': 'morning',
        'status': 'present',
        'marked_by': adminId,
      },
      {
        'student_id': student1['id'],
        'class_id': testClassId,
        'date': day2Str,
        'session': 'morning',
        'status': 'present',
        'marked_by': adminId,
      },
      {
        'student_id': student2['id'],
        'class_id': testClassId,
        'date': day1Str,
        'session': 'morning',
        'status': 'present',
        'marked_by': adminId,
      },
      {
        'student_id': student2['id'],
        'class_id': testClassId,
        'date': day2Str,
        'session': 'morning',
        'status': 'absent',
        'marked_by': adminId,
      },
    ]);
    print('Test attendance records inserted successfully.');

    // ── 4. Query Attendance Report via Repository ─────────────────────
    print('\n==========================================');
    print('STEP 5: Querying attendance report summary...');
    final summary = await reportRepo.getAttendanceReport(
      startDate: day1,
      endDate: day2,
      classId: testClassId,
      session: 'morning',
    );

    print('Report Summary Results:');
    print(' - Target Class: ${summary.className}');
    print(' - Low Attendance Threshold: ${summary.threshold}%');
    print(' - Total Evaluated Students: ${summary.totalStudents}');
    print(' - Total Recorded Sessions: ${summary.totalSessions}');
    print(' - Overall Attendance Rate: ${summary.overallPercentage.toStringAsFixed(1)}%');
    print(' - Students Below Threshold: ${summary.lowAttendanceCount}');

    expect(summary.threshold, equals(75.0));
    expect(summary.totalSessions, equals(4)); // 2 for student1 + 2 for student2
    expect(summary.totalPresent, equals(3));
    expect(summary.totalAbsent, equals(1));
    expect(summary.overallPercentage, closeTo(75.0, 0.01));

    // Verify individual student calculations
    final s1Report = summary.students.firstWhere((s) => s.studentId == student1['id']);
    final s2Report = summary.students.firstWhere((s) => s.studentId == student2['id']);

    print('Student 1 Rate: ${s1Report.attendancePercentage}% (Low: ${s1Report.isLowAttendance(summary.threshold)})');
    print('Student 2 Rate: ${s2Report.attendancePercentage}% (Low: ${s2Report.isLowAttendance(summary.threshold)})');

    expect(s1Report.attendancePercentage, equals(100.0));
    expect(s1Report.isLowAttendance(summary.threshold), isFalse);

    expect(s2Report.attendancePercentage, equals(50.0));
    expect(s2Report.isLowAttendance(summary.threshold), isTrue);
    expect(summary.lowAttendanceCount, greaterThanOrEqualTo(1));

    // Verify daily trend calculation
    expect(summary.dailyTrends.length, equals(2));
    print('Daily Trends:');
    for (final t in summary.dailyTrends) {
      print(' - ${t.formattedDate}: Present=${t.presentCount}, Absent=${t.absentCount}, Rate=${t.attendancePercentage.toStringAsFixed(1)}%');
    }

    // ── 5. Test CSV Export Service ─────────────────────────────────────
    print('\n==========================================');
    print('STEP 6: Generating CSV export...');
    final csvString = CsvExportService.generateCsv(summary);
    expect(csvString, isNotEmpty);
    expect(csvString, contains('SCHOOL ATTENDANCE REPORT'));
    expect(csvString, contains(testClassName));
    expect(csvString, contains('Roll No,Student Name,Class'));
    expect(csvString, contains(student1['name']));
    expect(csvString, contains(student2['name']));
    expect(csvString, contains('BELOW THRESHOLD (<75%)'));
    print('CSV generated successfully! Length: ${csvString.length} characters.');
    print('CSV Preview:\n${csvString.split('\n').take(12).join('\n')}');

    // ── 6. Test PDF Export Service ─────────────────────────────────────
    print('\n==========================================');
    print('STEP 7: Generating printable PDF export bytes...');
    final pdfBytes = await PdfExportService.generatePdfBytes(summary);
    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.length, greaterThan(1000));
    // PDF Magic Header %PDF-
    expect(pdfBytes[0], equals(0x25)); // %
    expect(pdfBytes[1], equals(0x50)); // P
    expect(pdfBytes[2], equals(0x44)); // D
    expect(pdfBytes[3], equals(0x46)); // F
    print('PDF generated successfully! Byte size: ${pdfBytes.length} bytes.');

    // ── 7. Clean up test records ──────────────────────────────────────
    print('\n==========================================');
    print('STEP 8: Cleaning up test attendance records...');
    await client
        .from('attendance')
        .delete()
        .eq('class_id', testClassId)
        .inFilter('date', [day1Str, day2Str]);
    print('Cleaned up test attendance records.');

    print('\n==========================================');
    print('SUCCESS: Phase 9 Reports, Analytics & Exports fully verified!');
  });
}
