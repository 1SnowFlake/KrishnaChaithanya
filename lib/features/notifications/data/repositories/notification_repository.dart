import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/notifications/domain/models/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository handling notifications retrieval, read status, and missing-attendance scanning.
class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  /// Fetches notifications visible to the current user.
  /// For Admins: includes broadcast alerts (`user_id IS NULL`) and direct messages.
  /// For Teachers: includes only their direct messages.
  Future<List<NotificationModel>> getNotifications({int limit = 50}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // Query profiles to check role
    final profileRes = await _supabase
        .from(AppConstants.tableProfiles)
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final isAdmin = profileRes?['role'] == AppConstants.roleAdmin;

    var query = _supabase.from(AppConstants.tableNotifications).select();

    if (isAdmin) {
      // Admins see broadcasts + direct
      query = query.or('user_id.is.null,user_id.eq.${user.id}');
    } else {
      // Teachers see direct only
      query = query.eq('user_id', user.id);
    }

    final response = await query.order('created_at', ascending: false).limit(limit);
    final list = (response as List).cast<Map<String, dynamic>>();

    return list.map((item) => NotificationModel.fromMap(item)).toList();
  }

  /// Marks an individual notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from(AppConstants.tableNotifications)
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Marks all visible unread notifications as read.
  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final profileRes = await _supabase
        .from(AppConstants.tableProfiles)
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final isAdmin = profileRes?['role'] == AppConstants.roleAdmin;

    var query = _supabase
        .from(AppConstants.tableNotifications)
        .update({'is_read': true})
        .eq('is_read', false);

    if (isAdmin) {
      await query.or('user_id.is.null,user_id.eq.${user.id}');
    } else {
      await query.eq('user_id', user.id);
    }
  }

  /// Deletes a notification (Admin or owner).
  Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from(AppConstants.tableNotifications)
        .delete()
        .eq('id', notificationId);
  }

  /// Scans for missing attendance across all classes for today and creates
  /// alert notifications for admins and primary teachers.
  /// Returns the number of new notifications dispatched.
  Future<int> scanMissingAttendance({bool forceCheck = false}) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // 1. Fetch settings for cutoffs
    final settingsRes = await _supabase
        .from(AppConstants.tableSettings)
        .select('morning_cutoff, afternoon_cutoff, allow_holiday_attendance')
        .maybeSingle();

    final mCutoffStr = settingsRes?['morning_cutoff'] as String? ?? '10:30:00';
    final aCutoffStr = settingsRes?['afternoon_cutoff'] as String? ?? '14:30:00';

    final mParts = mCutoffStr.split(':').map(int.parse).toList();
    final aParts = aCutoffStr.split(':').map(int.parse).toList();

    final mTime = DateTime(now.year, now.month, now.day, mParts[0], mParts[1]);
    final aTime = DateTime(now.year, now.month, now.day, aParts[0], aParts[1]);

    final isMorningPast = forceCheck || now.isAfter(mTime);
    final isAfternoonPast = forceCheck || now.isAfter(aTime);

    if (!isMorningPast && !isAfternoonPast) {
      // Cutoffs have not passed yet; nothing missing
      return 0;
    }

    // 2. Fetch all classes
    final classesRes = await _supabase
        .from(AppConstants.tableClasses)
        .select('id, name, primary_teacher_id')
        .order('name');
    final classes = (classesRes as List).cast<Map<String, dynamic>>();

    // 3. Fetch existing attendance for today
    final attendanceRes = await _supabase
        .from(AppConstants.tableAttendance)
        .select('class_id, session')
        .eq('date', todayStr);
    final attendanceList = (attendanceRes as List).cast<Map<String, dynamic>>();

    final submittedSessions = <String>{}; // "classId_session"
    for (final row in attendanceList) {
      submittedSessions.add('${row['class_id']}_${row['session']}');
    }

    // 4. Fetch existing notifications created today to prevent duplicate spam
    final existingNotifsRes = await _supabase
        .from(AppConstants.tableNotifications)
        .select('message')
        .eq('type', 'missing_attendance')
        .gte('created_at', '${todayStr}T00:00:00');
    final existingNotifs = (existingNotifsRes as List).cast<Map<String, dynamic>>();
    final existingMessages = existingNotifs.map((n) => n['message'] as String).toSet();

    final newNotifications = <Map<String, dynamic>>[];

    for (final cls in classes) {
      final classId = cls['id'] as String;
      final className = cls['name'] as String;
      final primaryTeacherId = cls['primary_teacher_id'] as String?;

      // Check Morning session
      if (isMorningPast && !submittedSessions.contains('${classId}_morning')) {
        final alertMsg = 'Morning attendance for $className was not submitted before cutoff ($mCutoffStr).';
        if (!existingMessages.contains(alertMsg)) {
          existingMessages.add(alertMsg);
          // Broadcast to Admins
          newNotifications.add({
            'user_id': null,
            'type': 'missing_attendance',
            'message': alertMsg,
            'is_read': false,
            'metadata': {
              'title': 'Missing Attendance: $className (Morning)',
              'class_id': classId,
              'session': 'morning',
              'date': todayStr,
            },
          });

          // Direct alert to primary teacher if assigned
          if (primaryTeacherId != null && primaryTeacherId.isNotEmpty) {
            newNotifications.add({
              'user_id': primaryTeacherId,
              'type': 'missing_attendance',
              'message': 'You have not submitted Morning attendance for $className. Please submit or contact Admin.',
              'is_read': false,
              'metadata': {
                'title': 'Action Required: Morning Attendance Pending',
                'class_id': classId,
                'session': 'morning',
                'date': todayStr,
              },
            });
          }
        }
      }

      // Check Afternoon session
      if (isAfternoonPast && !submittedSessions.contains('${classId}_afternoon')) {
        final alertMsg = 'Afternoon attendance for $className was not submitted before cutoff ($aCutoffStr).';
        if (!existingMessages.contains(alertMsg)) {
          existingMessages.add(alertMsg);
          // Broadcast to Admins
          newNotifications.add({
            'user_id': null,
            'type': 'missing_attendance',
            'message': alertMsg,
            'is_read': false,
            'metadata': {
              'title': 'Missing Attendance: $className (Afternoon)',
              'class_id': classId,
              'session': 'afternoon',
              'date': todayStr,
            },
          });

          // Direct alert to primary teacher
          if (primaryTeacherId != null && primaryTeacherId.isNotEmpty) {
            newNotifications.add({
              'user_id': primaryTeacherId,
              'type': 'missing_attendance',
              'message': 'You have not submitted Afternoon attendance for $className. Please submit or contact Admin.',
              'is_read': false,
              'metadata': {
                'title': 'Action Required: Afternoon Attendance Pending',
                'class_id': classId,
                'session': 'afternoon',
                'date': todayStr,
              },
            });
          }
        }
      }
    }

    if (newNotifications.isNotEmpty) {
      await _supabase.from(AppConstants.tableNotifications).insert(newNotifications);
    }

    return newNotifications.length;
  }
}
