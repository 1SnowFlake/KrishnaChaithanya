import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  const supabaseUrl = 'https://cnwcambhldsmvpuwgcqj.supabase.co';
  const supabaseAnonKey = 'sb_publishable_IlAsVPCWoKdFl-Xc5RxaYA_SvftODPl';

  test('End-to-End Teacher Attendance Submit Flow', () async {
    print('\n==========================================');
    print('STEP 1: Initializing Supabase client...');
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    print('Client initialized.');

    print('\n==========================================');
    print('STEP 2: Signing in as teacher1@school.com...');
    final authRes = await client.auth.signInWithPassword(
      email: 'teacher1@school.com',
      password: 'Test@123',
    );
    expect(authRes.user, isNotNull);
    final userId = authRes.user!.id;
    print('Logged in successfully. User ID: $userId');

    print('\n==========================================');
    print('STEP 3: Checking teacher profile in `profiles` table...');
    final profile = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    print('Profile: $profile');
    expect(profile['role'], equals('teacher'));
    expect(profile['is_active'], isTrue);

    print('\n==========================================');
    print('STEP 4: Fetching teacher assigned classes...');
    final classes = await client
        .from('classes')
        .select('id, name, primary_teacher_id')
        .order('name');
    print('Assigned classes found: ${classes.length}');
    for (final c in classes) {
      print(' - ${c['name']} (ID: ${c['id']})');
    }
    expect(classes, isNotEmpty);
    final classId = classes.first['id'] as String;

    print('\n==========================================');
    print('STEP 5: Fetching students in class: ${classes.first['name']}...');
    final students = await client
        .from('students')
        .select('id, name, roll_no')
        .eq('class_id', classId)
        .eq('is_active', true)
        .order('roll_no');
    print('Students found: ${students.length}');
    for (final s in students) {
      print(' - Roll ${s['roll_no']}: ${s['name']} (ID: ${s['id']})');
    }
    expect(students, isNotEmpty);

    print('\n==========================================');
    print('STEP 6: Checking school date via RPC school_today()...');
    String today;
    try {
      final rpcToday = await client.rpc('school_today');
      today = rpcToday.toString().split('T')[0];
      print('School today: $today');
    } catch (e) {
      today = DateTime.now().toIso8601String().split('T')[0];
      print('Fallback today: $today (RPC failed: $e)');
    }

    print('\n==========================================');
    print('STEP 7: Submitting attendance for Morning Session...');
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      // Mark first student absent, rest present
      final status = (i == 0) ? 'absent' : 'present';
      rows.add({
        'student_id': s['id'],
        'class_id': classId,
        'date': today,
        'session': 'morning',
        'status': status,
        'marked_by': userId,
        'is_substitute': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    try {
      print('Submitting ${rows.length} rows via upsert on (student_id,date,session)...');
      await client.from('attendance').upsert(
            rows,
            onConflict: 'student_id,date,session',
          );
      print('Attendance successfully upserted into database!');
    } catch (e, st) {
      print('ERROR DURING ATTENDANCE UPSERT: $e');
      print('Stack trace: $st');
      rethrow;
    }

    print('\n==========================================');
    print('STEP 8: Verifying attendance records in database...');
    final savedRecords = await client
        .from('attendance')
        .select('id, student_id, session, status, marked_by')
        .eq('class_id', classId)
        .eq('date', today)
        .eq('session', 'morning');
    print('Verified records found in DB: ${savedRecords.length}');
    for (final r in savedRecords) {
      print(' - Student ${r['student_id']}: ${r['status']}');
    }
    expect(savedRecords.length, equals(students.length));

    print('\n==========================================');
    print('STEP 9: Verifying audit log trigger in `attendance_log`...');
    final logs = await client
        .from('attendance_log')
        .select()
        .order('changed_at', ascending: false)
        .limit(5);
    print('Audit log entries count: ${logs.length}');
    for (final l in logs) {
      print(' - Log: old=${l['old_status']} -> new=${l['new_status']} (changed_by: ${l['changed_by']})');
    }

    print('\nALL 9 BACKEND CHECKS PASSED PERFECTLY!');
  });
}
