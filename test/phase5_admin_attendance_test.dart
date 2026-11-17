import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/attendance/data/repositories/attendance_admin_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const supabaseUrl = 'https://cnwcambhldsmvpuwgcqj.supabase.co';
  const supabaseAnonKey = 'sb_publishable_IlAsVPCWoKdFl-Xc5RxaYA_SvftODPl';

  test('Phase 5 E2E: Admin Attendance Override & Live Audit Log Verification', () async {
    print('\n==========================================');
    print('STEP 1: Initializing Supabase client...');
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

    print('\n==========================================');
    print('STEP 2: Signing in as admin@school.com...');
    final authRes = await client.auth.signInWithPassword(
      email: 'admin@school.com',
      password: 'Test@123',
    );
    expect(authRes.user, isNotNull);
    final adminId = authRes.user!.id;
    print('Logged in successfully as Admin: $adminId');

    print('\n==========================================');
    print('STEP 3: Fetching classes...');
    final classesRes = await client.from(AppConstants.tableClasses).select('id, name').limit(1);
    expect((classesRes as List).isNotEmpty, isTrue);
    final classId = classesRes.first['id'] as String;
    final className = classesRes.first['name'] as String;
    print('Testing with class: $className ($classId)');

    print('\n==========================================');
    print('STEP 4: Fetching active students in class...');
    final studentsRes = await client
        .from(AppConstants.tableStudents)
        .select('id, name, roll_no')
        .eq('class_id', classId)
        .eq('is_active', true)
        .limit(1);
    expect((studentsRes as List).isNotEmpty, isTrue);
    final studentId = studentsRes.first['id'] as String;
    final studentName = studentsRes.first['name'] as String;
    print('Testing with student: $studentName ($studentId)');

    final adminRepo = AttendanceAdminRepository(supabaseClient: client);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    const session = AppConstants.sessionMorning;

    print('\n==========================================');
    print('STEP 5: Fetching admin attendance records...');
    final recordsBefore = await adminRepo.getClassAttendance(
      classId: classId,
      date: todayStr,
      session: session,
    );
    expect(recordsBefore, isNotEmpty);
    final targetRecord = recordsBefore.firstWhere((r) => r.studentId == studentId);
    final oldStatus = targetRecord.status;
    final newStatus = (oldStatus == AppConstants.statusPresent)
        ? AppConstants.statusAbsent
        : AppConstants.statusPresent;

    print('Modifying student $studentName: ${oldStatus ?? "UNMARKED"} -> $newStatus');

    print('\n==========================================');
    print('STEP 6: Admin saving attendance override...');
    await adminRepo.saveStudentAttendance(
      record: targetRecord,
      newStatus: newStatus,
      adminId: adminId,
    );

    print('\n==========================================');
    print('STEP 7: Verifying attendance record in database...');
    final recordsAfter = await adminRepo.getClassAttendance(
      classId: classId,
      date: todayStr,
      session: session,
    );
    final updatedRecord = recordsAfter.firstWhere((r) => r.studentId == studentId);
    expect(updatedRecord.status, equals(newStatus));
    print('Verified attendance table: student status is now ${updatedRecord.status}');

    print('\n==========================================');
    print('STEP 8: Verifying live Audit Trail in attendance_log...');
    final auditLogs = await adminRepo.getAuditLogs(
      classId: classId,
      date: todayStr,
      limit: 10,
    );
    expect(auditLogs, isNotEmpty);

    final matchingLog = auditLogs.firstWhere((l) => l.studentName == studentName);
    print('Found Audit Log Entry:');
    print(' - Student: ${matchingLog.studentName} (Roll: ${matchingLog.rollNo})');
    print(' - Class: ${matchingLog.className} (${matchingLog.session})');
    print(' - Transition: ${matchingLog.oldStatus ?? "NULL"} -> ${matchingLog.newStatus}');
    print(' - Changed By: ${matchingLog.changedByName} (${matchingLog.changedByRole})');
    print(' - Timestamp: ${matchingLog.changedAt}');

    expect(matchingLog.newStatus, equals(newStatus));
    expect(matchingLog.changedByRole, equals(AppConstants.roleAdmin));

    // Clean up test attendance row so it doesn't leak into other tests
    await client
        .from(AppConstants.tableAttendance)
        .delete()
        .eq('student_id', studentId)
        .eq('date', todayStr)
        .eq('session', session);
    print('Cleaned up Phase 5 test attendance record.');

    print('\n==========================================');
    print('SUCCESS: Phase 5 Admin Attendance Override & Live Audit Trail fully verified!');
  });
}
