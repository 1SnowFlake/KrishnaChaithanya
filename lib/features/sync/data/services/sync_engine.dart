import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/outbox_item_model.dart';
import '../local/app_local_database.dart';
import 'connectivity_service.dart';

/// Result summary of an outbox sync execution.
class SyncResult {
  final int totalProcessed;
  final int successful;
  final int failed;
  final bool isOnline;
  final List<String> errors;

  const SyncResult({
    required this.totalProcessed,
    required this.successful,
    required this.failed,
    required this.isOnline,
    this.errors = const [],
  });
}

/// Synchronization engine orchestrating offline queueing, background syncing,
/// roster caching, and server conflict resolution.
class SyncEngine {
  final AppLocalDatabase _localDb;
  final SupabaseClient _supabase;
  final ConnectivityService _connectivity;
  final Uuid _uuid = const Uuid();

  SyncEngine({
    required AppLocalDatabase localDb,
    SupabaseClient? supabase,
    ConnectivityService? connectivity,
  })  : _localDb = localDb,
        _supabase = supabase ?? Supabase.instance.client,
        _connectivity = connectivity ?? ConnectivityService();

  /// Queues attendance submissions into local outbox and local cache.
  void queueAttendanceBatch({
    required String classId,
    required String date,
    required String session,
    required String markedBy,
    required bool isSubstitute,
    required Map<String, String> studentStatuses, // studentId -> 'present' / 'absent'
  }) {
    final now = DateTime.now();
    final outboxItems = <OutboxItemModel>[];
    final cacheItems = <Map<String, dynamic>>[];

    for (final entry in studentStatuses.entries) {
      final id = _uuid.v4();
      final item = OutboxItemModel(
        id: id,
        studentId: entry.key,
        classId: classId,
        date: date,
        session: session,
        status: entry.value,
        markedBy: markedBy,
        isSubstitute: isSubstitute,
        createdAt: now,
        syncStatus: 'pending',
      );
      outboxItems.add(item);
      cacheItems.add({
        'id': id,
        'student_id': entry.key,
        'class_id': classId,
        'date': date,
        'session': session,
        'status': entry.value,
        'marked_by': markedBy,
        'is_substitute': isSubstitute,
      });
    }

    _localDb.queueBatchAttendance(outboxItems);
    _localDb.cacheAttendance(cacheItems);
  }

  /// Processes pending outbox items and pushes them to Supabase.
  /// Enforces idempotency and server ID preservation to respect foreign key audit logs.
  Future<SyncResult> syncPendingOutbox() async {
    final isOnline = await _connectivity.checkOnline();
    if (!isOnline) {
      return const SyncResult(
        totalProcessed: 0,
        successful: 0,
        failed: 0,
        isOnline: false,
      );
    }

    final pending = _localDb.getPendingOutboxItems();
    if (pending.isEmpty) {
      return const SyncResult(
        totalProcessed: 0,
        successful: 0,
        failed: 0,
        isOnline: true,
      );
    }

    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (final item in pending) {
      _localDb.updateOutboxStatus(item.id, 'syncing');

      try {
        // 1. Check if a record already exists on server for (student_id, date, session)
        final existing = await _supabase
            .from('attendance')
            .select('id, status, marked_by, updated_at')
            .eq('student_id', item.studentId)
            .eq('date', item.date)
            .eq('session', item.session)
            .maybeSingle();

        if (existing == null) {
          // INSERT new record
          await _supabase.from('attendance').insert({
            'id': item.id,
            'student_id': item.studentId,
            'class_id': item.classId,
            'date': item.date,
            'session': item.session,
            'status': item.status,
            'marked_by': item.markedBy,
            'is_substitute': item.isSubstitute,
          });
        } else {
          // Record already exists:
          // If status is identical, consider it already synced
          if (existing['status'] == item.status) {
            // Already synced on server
          } else {
            // Conflict resolution: apply update while strictly preserving existing server row ID
            final serverId = existing['id'] as String;
            await _supabase.from('attendance').update({
              'status': item.status,
              'marked_by': item.markedBy,
              'is_substitute': item.isSubstitute,
            }).eq('id', serverId);
          }
        }

        // Successfully synchronized
        _localDb.updateOutboxStatus(item.id, 'synced');
        successCount++;
      } catch (e) {
        failCount++;
        final errMsg = e.toString();
        errors.add('Failed to sync student ${item.studentId}: $errMsg');
        _localDb.updateOutboxStatus(
          item.id,
          'failed',
          errorMessage: errMsg,
          retryCount: item.retryCount + 1,
        );
      }
    }

    // Clean up synced items
    _localDb.clearSyncedOutbox();

    return SyncResult(
      totalProcessed: pending.length,
      successful: successCount,
      failed: failCount,
      isOnline: true,
      errors: errors,
    );
  }

  /// Downloads teacher classes and students into SQLite cache.
  Future<void> syncRosterCache() async {
    final isOnline = await _connectivity.checkOnline();
    if (!isOnline) return;

    try {
      // 1. Cache classes
      final classesRes = await _supabase.from('classes').select('id, name, primary_teacher_id');
      final classList = List<Map<String, dynamic>>.from(classesRes as List);
      _localDb.cacheClasses(classList);

      // 2. Cache students
      final studentsRes = await _supabase.from('students').select('id, name, roll_no, class_id');
      final studentList = List<Map<String, dynamic>>.from(studentsRes as List);
      _localDb.cacheStudents(studentList);
    } catch (_) {
      // Silently continue if network fails
    }
  }

  /// Returns current number of unsynced outbox items.
  int getPendingCount() => _localDb.getPendingOutboxCount();
}
