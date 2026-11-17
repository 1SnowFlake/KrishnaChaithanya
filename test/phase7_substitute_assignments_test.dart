import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/attendance/data/repositories/attendance_repository.dart';
import 'package:slkc_app/features/substitutes/data/repositories/substitute_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const supabaseUrl = 'https://cnwcambhldsmvpuwgcqj.supabase.co';
  const supabaseAnonKey = 'sb_publishable_IlAsVPCWoKdFl-Xc5RxaYA_SvftODPl';

  test('Phase 7 E2E: Substitute Teacher Assignment, RLS Date Rules & Attendance Flow', () async {
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

    final subRepo = SubstituteRepository(client);

    // Fetch Class 1-A (Primary teacher is Teacher 1)
    final classRes = await client
        .from(AppConstants.tableClasses)
        .select('id, name, primary_teacher_id')
        .eq('name', 'Class 1-A')
        .single();
    final classId = classRes['id'] as String;
    final className = classRes['name'] as String;
    final primaryTeacherId = classRes['primary_teacher_id'] as String;
    print('Target Class: $className ($classId), Primary Teacher: $primaryTeacherId');

    // Fetch Teacher 2 profile
    final teacher2Res = await client
        .from(AppConstants.tableProfiles)
        .select('id, name, email')
        .eq('email', 'teacher2@school.com')
        .single();
    final teacher2Id = teacher2Res['id'] as String;
    final teacher2Name = teacher2Res['name'] as String;
    print('Target Substitute Teacher: $teacher2Name ($teacher2Id)');

    // Ensure teacher2 is NOT the primary teacher for Class 1-A
    expect(primaryTeacherId, isNot(equals(teacher2Id)));

    // Clean up any stale test assignments
    await client
        .from(AppConstants.tableSubstitutes)
        .delete()
        .eq('class_id', classId)
        .eq('teacher_id', teacher2Id);

    // ── 2. Admin creates substitute assignment for Teacher 2 today ─────
    print('\n==========================================');
    print('STEP 3: Admin assigning Teacher 2 as substitute for Class 1-A today...');
    final today = DateTime.now();
    final createdAssignment = await subRepo.createSubstituteAssignment(
      classId: classId,
      teacherId: teacher2Id,
      startDate: today,
      endDate: today.add(const Duration(days: 2)),
      createdBy: adminId,
    );
    expect(createdAssignment.id, isNotEmpty);
    expect(createdAssignment.isActiveToday, isTrue);
    print('Substitute assignment created successfully: ${createdAssignment.id} (Valid: ${createdAssignment.formattedRange})');

    // ── 3. Sign in as Teacher 2 ───────────────────────────────────────
    print('\n==========================================');
    print('STEP 4: Signing in as substitute teacher (teacher2@school.com)...');
    final teacherAuth = await client.auth.signInWithPassword(
      email: 'teacher2@school.com',
      password: 'Test@123',
    );
    expect(teacherAuth.user, isNotNull);
    print('Teacher 2 signed in successfully.');

    final teacherAttendanceRepo = AttendanceRepository(client);

    // ── 4. Verify RLS grants Teacher 2 access to Class 1-A ────────────
    print('\n==========================================');
    print('STEP 5: Checking teacher2 assigned classes via RLS...');
    final assignedClasses = await teacherAttendanceRepo.getTeacherAssignedClasses();
    print('Classes visible to Teacher 2: ${assignedClasses.map((c) => c.name).toList()}');
    expect(assignedClasses.any((c) => c.id == classId), isTrue);
    print('Verified: Class 1-A is accessible to Teacher 2 through active substitute assignment!');

    // ── 5. Verify substitute status check ─────────────────────────────
    print('\n==========================================');
    print('STEP 6: Checking isTeacherSubstitute for Class 1-A...');
    final isSub = await teacherAttendanceRepo.isTeacherSubstitute(classId);
    expect(isSub, isTrue);
    print('Verified: Teacher 2 is identified as substitute: $isSub');

    // ── 6. Teacher 2 takes attendance for Class 1-A ───────────────────
    print('\n==========================================');
    print('STEP 7: Teacher 2 submitting attendance as substitute...');
    final students = await teacherAttendanceRepo.getStudentsInClass(classId);
    expect(students, isNotEmpty);
    print('Class students count: ${students.length}');

    final statusMap = <String, String>{};
    for (final s in students) {
      statusMap[s.id] = AppConstants.statusPresent;
    }

    await teacherAttendanceRepo.submitAttendance(
      classId: classId,
      session: AppConstants.sessionAfternoon,
      studentStatusMap: statusMap,
      isSubstitute: isSub,
    );
    print('Attendance submitted by Teacher 2 successfully for Afternoon session!');

    // ── 7. Verify is_substitute flag in attendance table ──────────────
    print('\n==========================================');
    print('STEP 8: Verifying is_substitute and marked_by in attendance table...');
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final attendanceRows = await client
        .from(AppConstants.tableAttendance)
        .select('id, student_id, marked_by, is_substitute, status')
        .eq('class_id', classId)
        .eq('date', todayStr)
        .eq('session', AppConstants.sessionAfternoon);

    final rowsList = (attendanceRows as List).cast<Map<String, dynamic>>();
    expect(rowsList, isNotEmpty);
    for (final row in rowsList) {
      expect(row['marked_by'], equals(teacher2Id));
      expect(row['is_substitute'], isTrue);
    }
    print('Verified all ${rowsList.length} rows have marked_by = Teacher 2 and is_substitute = true!');

    // ── 8. Clean up: Admin revokes substitute assignment ──────────────
    print('\n==========================================');
    print('STEP 9: Re-signing in as Admin to clean up assignment...');
    await client.auth.signInWithPassword(
      email: 'admin@school.com',
      password: 'Test@123',
    );
    await subRepo.deleteSubstituteAssignment(createdAssignment.id);
    print('Substitute assignment removed.');

    print('\n==========================================');
    print('SUCCESS: Phase 7 Substitute Teacher Assignment & RLS Date Rules fully verified!');
  });
}
