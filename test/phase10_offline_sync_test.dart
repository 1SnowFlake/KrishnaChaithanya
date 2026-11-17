import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:slkc_app/features/sync/data/local/app_local_database.dart';
import 'package:slkc_app/features/sync/data/services/connectivity_service.dart';
import 'package:slkc_app/features/sync/data/services/sync_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestConnectivityService extends ConnectivityService {
  TestConnectivityService() : super(autoListen: false);

  @override
  Future<bool> checkOnline() async => true;
}

void main() {
  const supabaseUrl = 'https://cnwcambhldsmvpuwgcqj.supabase.co';
  const supabaseAnonKey = 'sb_publishable_IlAsVPCWoKdFl-Xc5RxaYA_SvftODPl';

  test('Phase 10 E2E: Local SQLite Cache, Outbox Queue, Offline Attendance & Sync Engine', () async {
    print('\n==========================================');
    print('STEP 1: Initializing local SQLite database...');
    final localDb = AppLocalDatabase();
    await localDb.init(inMemory: true);
    print('Local SQLite initialized successfully.');

    // ── 1. Test Local Roster Caching ──────────────────────────────────
    print('\n==========================================');
    print('STEP 2: Testing offline roster caching (classes & students)...');
    const testClassId = 'c0000000-0000-0000-0000-000000000001';
    localDb.cacheClasses([
      {
        'id': testClassId,
        'name': 'Class 1-A (Cached)',
        'primary_teacher_id': 'a0000000-0000-0000-0000-000000000002',
      }
    ]);

    localDb.cacheStudents([
      {
        'id': 's001',
        'name': 'Alice Offline',
        'roll_no': '1',
        'class_id': testClassId,
      },
      {
        'id': 's002',
        'name': 'Bob Offline',
        'roll_no': '2',
        'class_id': testClassId,
      },
    ]);

    final cachedClasses = localDb.getCachedClasses();
    expect(cachedClasses.length, equals(1));
    expect(cachedClasses.first['name'], equals('Class 1-A (Cached)'));

    final cachedStudents = localDb.getCachedStudents(testClassId);
    expect(cachedStudents.length, equals(2));
    expect(cachedStudents.first['name'], equals('Alice Offline'));
    print('Offline caching verified: ${cachedClasses.length} class, ${cachedStudents.length} students.');

    // ── 2. Initialize Supabase Client ─────────────────────────────────
    print('\n==========================================');
    print('STEP 3: Authenticating with Supabase backend...');
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

    // Sign in as Teacher 1 (who has primary access to Class 1-A)
    final teacherAuth = await client.auth.signInWithPassword(
      email: 'teacher1@school.com',
      password: 'Test@123',
    );
    expect(teacherAuth.user, isNotNull);
    final teacherId = teacherAuth.user!.id;
    print('Signed in as Teacher 1: $teacherId');

    // Fetch live student IDs for Class 1-A to use in sync testing
    final liveStudents = await client
        .from('students')
        .select('id, name, roll_no')
        .eq('class_id', testClassId)
        .order('roll_no');
    expect(liveStudents.length, greaterThanOrEqualTo(2));
    final liveS1 = liveStudents[0];
    final liveS2 = liveStudents[1];
    print('Live Students for Sync Test: ${liveS1['name']} & ${liveS2['name']}');

    // Clean up any existing attendance for today to ensure deterministic test run
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await client
        .from('attendance')
        .delete()
        .eq('class_id', testClassId)
        .eq('date', todayStr)
        .eq('session', 'morning');

    // ── 3. Test Offline Queueing (Outbox) ──────────────────────────────
    print('\n==========================================');
    print('STEP 4: Simulating offline attendance submission to SQLite Outbox...');
    final syncEngine = SyncEngine(
      localDb: localDb,
      supabase: client,
      connectivity: TestConnectivityService(),
    );

    // Queue 2 students while offline
    syncEngine.queueAttendanceBatch(
      classId: testClassId,
      date: todayStr,
      session: 'morning',
      markedBy: teacherId,
      isSubstitute: false,
      studentStatuses: {
        liveS1['id']: 'present',
        liveS2['id']: 'absent',
      },
    );

    expect(localDb.getPendingOutboxCount(), equals(2));
    final pendingItems = localDb.getPendingOutboxItems();
    expect(pendingItems.length, equals(2));
    expect(pendingItems.first.syncStatus, equals('pending'));
    print('Successfully queued ${pendingItems.length} records in SQLite outbox.');

    // ── 4. Test Idempotency (Updating Status in Outbox Before Sync) ────
    print('\n==========================================');
    print('STEP 5: Testing local outbox idempotency (modifying attendance before sync)...');
    // Change Student 2 from absent to present
    syncEngine.queueAttendanceBatch(
      classId: testClassId,
      date: todayStr,
      session: 'morning',
      markedBy: teacherId,
      isSubstitute: false,
      studentStatuses: {
        liveS2['id']: 'present',
      },
    );

    // Count should still be 2 (NO duplicates created!)
    expect(localDb.getPendingOutboxCount(), equals(2));
    final updatedItem = localDb.getPendingOutboxItems().firstWhere((i) => i.studentId == liveS2['id']);
    expect(updatedItem.status, equals('present'));
    print('Verified: Outbox is idempotent and updated student status to present without duplicating rows.');

    // ── 5. Run Sync Engine to Push to Supabase ────────────────────────
    print('\n==========================================');
    print('STEP 6: Running SyncEngine to synchronize outbox to Supabase...');
    final syncResult = await syncEngine.syncPendingOutbox();
    print('Sync Engine Result:');
    print(' - Processed: ${syncResult.totalProcessed}');
    print(' - Successful: ${syncResult.successful}');
    print(' - Failed: ${syncResult.failed}');
    if (syncResult.errors.isNotEmpty) {
      print(' - Errors: ${syncResult.errors}');
    }

    expect(syncResult.successful, equals(2));
    expect(syncResult.failed, equals(0));

    // Verify outbox was purged of synced records
    expect(localDb.getPendingOutboxCount(), equals(0));
    print('Outbox queue is now 0 (all synced items cleared).');

    // ── 6. Verify Records in Live Supabase Attendance Table ───────────
    print('\n==========================================');
    print('STEP 7: Verifying synchronized records in Supabase attendance table...');
    final liveAttendance = await client
        .from('attendance')
        .select('id, student_id, status, marked_by')
        .eq('class_id', testClassId)
        .eq('date', todayStr)
        .eq('session', 'morning');

    expect(liveAttendance, isNotEmpty);
    final att1 = liveAttendance.firstWhere((a) => a['student_id'] == liveS1['id']);
    final att2 = liveAttendance.firstWhere((a) => a['student_id'] == liveS2['id']);
    expect(att1['status'], equals('present'));
    expect(att2['status'], equals('present'));
    expect(att1['marked_by'], equals(teacherId));
    print('Server verification passed: Both students marked present by $teacherId.');

    // ── 7. Test Conflict Resolution & Audit Trail Preservation ─────────
    print('\n==========================================');
    print('STEP 8: Testing conflict resolution & audit trail preservation on re-sync...');
    // Queue an update for Student 1: present -> absent
    syncEngine.queueAttendanceBatch(
      classId: testClassId,
      date: todayStr,
      session: 'morning',
      markedBy: teacherId,
      isSubstitute: false,
      studentStatuses: {
        liveS1['id']: 'absent',
      },
    );
    expect(localDb.getPendingOutboxCount(), equals(1));

    // Run sync again
    final reSyncResult = await syncEngine.syncPendingOutbox();
    expect(reSyncResult.successful, equals(1));
    expect(reSyncResult.failed, equals(0));

    // Verify row ID in Supabase was PRESERVED and status changed to absent
    final reCheck = await client
        .from('attendance')
        .select('id, student_id, status')
        .eq('student_id', liveS1['id'])
        .eq('date', todayStr)
        .eq('session', 'morning')
        .single();

    expect(reCheck['id'], equals(att1['id']), reason: 'Existing server ID must be preserved for FK audit log integrity');
    expect(reCheck['status'], equals('absent'));
    print('Conflict resolution verified: Server row ID preserved and status updated to absent.');

    // ── 8. Clean Up Test Records ──────────────────────────────────────
    print('\n==========================================');
    print('STEP 9: Re-authenticating as Admin to clean up test attendance records...');
    await client.auth.signInWithPassword(
      email: 'admin@school.com',
      password: 'Test@123',
    );
    await client
        .from('attendance')
        .delete()
        .eq('class_id', testClassId)
        .eq('date', todayStr)
        .eq('session', 'morning');
    print('Cleaned up test attendance records as Admin.');

    localDb.dispose();
    print('\n==========================================');
    print('SUCCESS: Phase 10 Offline Mode, SQLite Outbox & Sync Engine fully verified!');
  });
}
