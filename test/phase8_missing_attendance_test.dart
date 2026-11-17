import 'package:flutter_test/flutter_test.dart';
import 'package:slkc_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const supabaseUrl = 'https://cnwcambhldsmvpuwgcqj.supabase.co';
  const supabaseAnonKey = 'sb_publishable_IlAsVPCWoKdFl-Xc5RxaYA_SvftODPl';

  test('Phase 8 E2E: Missing Attendance Scanning, Alerts & In-App Notifications Flow', () async {
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

    final notifRepo = NotificationRepository(client);

    // ── 2. Run missing attendance alert scan ───────────────────────────
    print('\n==========================================');
    print('STEP 3: Triggering missing attendance scan...');
    final alertsCount = await notifRepo.scanMissingAttendance(forceCheck: true);
    print('Dispatched alerts count from scan: $alertsCount');

    // ── 3. Verify Admin can read broadcast notifications ──────────────
    print('\n==========================================');
    print('STEP 4: Fetching admin notifications...');
    final adminNotifs = await notifRepo.getNotifications();
    expect(adminNotifs, isNotEmpty);
    print('Admin visible notifications count: ${adminNotifs.length}');

    final firstNotif = adminNotifs.first;
    print('Sample Notification: "${firstNotif.title}" - ${firstNotif.message}');
    print(' - Is Read: ${firstNotif.isRead}');
    print(' - Type: ${firstNotif.type}');
    print(' - Created: ${firstNotif.formattedTime}');

    // ── 4. Test markAsRead individual notification ────────────────────
    print('\n==========================================');
    print('STEP 5: Marking individual notification as read...');
    await notifRepo.markAsRead(firstNotif.id);

    final refreshedList = await notifRepo.getNotifications();
    final verifiedNotif = refreshedList.firstWhere((n) => n.id == firstNotif.id);
    expect(verifiedNotif.isRead, isTrue);
    print('Successfully verified notification ${firstNotif.id} marked as read!');

    // ── 5. Test markAllAsRead ─────────────────────────────────────────
    print('\n==========================================');
    print('STEP 6: Marking all notifications as read...');
    await notifRepo.markAllAsRead();

    final allReadList = await notifRepo.getNotifications();
    final unreadCount = allReadList.where((n) => !n.isRead).length;
    expect(unreadCount, equals(0));
    print('Verified: All notifications are marked as read (Unread count: $unreadCount)');

    // ── 6. Test Teacher direct notification delivery ──────────────────
    print('\n==========================================');
    print('STEP 7: Signing in as teacher1@school.com to test recipient RLS...');
    final teacherAuth = await client.auth.signInWithPassword(
      email: 'teacher1@school.com',
      password: 'Test@123',
    );
    expect(teacherAuth.user, isNotNull);
    final teacher1Id = teacherAuth.user!.id;

    final teacherNotifs = await notifRepo.getNotifications();
    print('Teacher visible notifications count: ${teacherNotifs.length}');
    for (final tn in teacherNotifs) {
      expect(tn.userId, equals(teacher1Id));
      print(' - Teacher Alert: "${tn.title}"');
    }

    // ── 7. Clean up test notifications ────────────────────────────────
    print('\n==========================================');
    print('STEP 8: Re-authenticating as Admin to clean up test notifications...');
    await client.auth.signInWithPassword(
      email: 'admin@school.com',
      password: 'Test@123',
    );

    // Delete notifications created in this test run
    for (final n in adminNotifs) {
      await notifRepo.deleteNotification(n.id);
    }
    print('Cleaned up test notifications.');

    print('\n==========================================');
    print('SUCCESS: Phase 8 Missing Attendance Alerts & In-App Notifications fully verified!');
  });
}
