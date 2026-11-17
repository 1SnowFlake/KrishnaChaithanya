import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/outbox_item_model.dart';

/// Local SQLite database handling offline attendance outbox queue and local cached data
/// on native platforms (Android, iOS, Windows, macOS, Linux).
class AppLocalDatabase {
  Database? _db;

  AppLocalDatabase([Database? db]) : _db = db;

  /// Returns active SQLite instance, initializing if necessary.
  Database get database {
    if (_db == null) {
      throw StateError('AppLocalDatabase is not initialized. Call init() first.');
    }
    return _db!;
  }

  /// Initializes the SQLite database on disk or in-memory.
  Future<void> init({bool inMemory = false}) async {
    if (_db != null) return;

    if (inMemory || kIsWeb) {
      _db = sqlite3.openInMemory();
    } else {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final dbPath = p.join(docsDir.path, 'slkc_offline_attendance.db');
        _db = sqlite3.open(dbPath);
      } catch (e) {
        // Fallback to in-memory if disk path inaccessible
        _db = sqlite3.openInMemory();
      }
    }

    _createTables();
  }

  void _createTables() {
    final db = database;

    db.execute('''
      CREATE TABLE IF NOT EXISTS cached_classes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        primary_teacher_id TEXT,
        synced_at TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS cached_students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        roll_no TEXT NOT NULL,
        class_id TEXT NOT NULL,
        synced_at TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_outbox (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        date TEXT NOT NULL,
        session TEXT NOT NULL,
        status TEXT NOT NULL,
        marked_by TEXT NOT NULL,
        is_substitute INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        UNIQUE (student_id, date, session)
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS cached_attendance (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        date TEXT NOT NULL,
        session TEXT NOT NULL,
        status TEXT NOT NULL,
        marked_by TEXT NOT NULL,
        is_substitute INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        UNIQUE (student_id, date, session)
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS app_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_attendance (
        id TEXT PRIMARY KEY,
        teacher_id TEXT NOT NULL,
        date TEXT NOT NULL,
        session TEXT NOT NULL,
        status TEXT NOT NULL,
        marked_by TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (teacher_id, date, session)
      );
    ''');
  }

  // ============================================================
  // PREFERENCE OPERATIONS
  // ============================================================

  /// Sets a persistent key-value preference in local SQLite.
  void setPreference(String key, String value) {
    final stmt = database.prepare('''
      INSERT INTO app_preferences (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
    ''');
    stmt.execute([key, value]);
    stmt.dispose();
  }

  /// Retrieves a persistent key-value preference from local SQLite.
  String? getPreference(String key) {
    final stmt = database.prepare('SELECT value FROM app_preferences WHERE key = ?;');
    final result = stmt.select([key]);
    stmt.dispose();
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  // ============================================================
  // OUTBOX OPERATIONS
  // ============================================================

  /// Adds or updates an attendance record in the outbox queue.
  void queueAttendance(OutboxItemModel item) {
    final stmt = database.prepare('''
      INSERT INTO attendance_outbox (
        id, student_id, class_id, date, session, status, marked_by,
        is_substitute, created_at, sync_status, error_message, retry_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(student_id, date, session) DO UPDATE SET
        status = excluded.status,
        marked_by = excluded.marked_by,
        is_substitute = excluded.is_substitute,
        created_at = excluded.created_at,
        sync_status = 'pending',
        error_message = NULL;
    ''');

    stmt.execute([
      item.id,
      item.studentId,
      item.classId,
      item.date,
      item.session,
      item.status,
      item.markedBy,
      item.isSubstitute ? 1 : 0,
      item.createdAt.toIso8601String(),
      item.syncStatus,
      item.errorMessage,
      item.retryCount,
    ]);
    stmt.dispose();
  }

  /// Queues a batch of attendance records inside an ACID transaction.
  void queueBatchAttendance(List<OutboxItemModel> items) {
    if (items.isEmpty) return;
    database.execute('BEGIN TRANSACTION;');
    try {
      for (final item in items) {
        queueAttendance(item);
      }
      database.execute('COMMIT;');
    } catch (e) {
      database.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Retrieves all outbox records waiting to sync (pending or failed).
  List<OutboxItemModel> getPendingOutboxItems() {
    final ResultSet results = database.select('''
      SELECT * FROM attendance_outbox
      WHERE sync_status IN ('pending', 'failed')
      ORDER BY created_at ASC;
    ''');

    return results.map((row) => OutboxItemModel.fromMap(row)).toList();
  }

  /// Returns the count of pending outbox records.
  int getPendingOutboxCount() {
    final ResultSet result = database.select('''
      SELECT COUNT(*) as count FROM attendance_outbox
      WHERE sync_status IN ('pending', 'failed');
    ''');
    return result.first['count'] as int? ?? 0;
  }

  /// Updates status of an outbox item.
  void updateOutboxStatus(
    String id,
    String status, {
    String? errorMessage,
    int? retryCount,
  }) {
    if (errorMessage != null || retryCount != null) {
      final stmt = database.prepare('''
        UPDATE attendance_outbox
        SET sync_status = ?, error_message = ?, retry_count = COALESCE(?, retry_count)
        WHERE id = ?;
      ''');
      stmt.execute([status, errorMessage, retryCount, id]);
      stmt.dispose();
    } else {
      final stmt = database.prepare('''
        UPDATE attendance_outbox
        SET sync_status = ?
        WHERE id = ?;
      ''');
      stmt.execute([status, id]);
      stmt.dispose();
    }
  }

  /// Deletes a specific item from the outbox.
  void deleteOutboxItem(String id) {
    final stmt = database.prepare('DELETE FROM attendance_outbox WHERE id = ?;');
    stmt.execute([id]);
    stmt.dispose();
  }

  /// Cleans up synced items older than 24 hours to keep database lean.
  void clearSyncedOutbox() {
    database.execute("DELETE FROM attendance_outbox WHERE sync_status = 'synced';");
  }

  // ============================================================
  // CACHE OPERATIONS: CLASSES & STUDENTS
  // ============================================================

  /// Caches classes locally for offline lookup.
  void cacheClasses(List<Map<String, dynamic>> classes) {
    final now = DateTime.now().toIso8601String();
    database.execute('BEGIN TRANSACTION;');
    try {
      final stmt = database.prepare('''
        INSERT INTO cached_classes (id, name, primary_teacher_id, synced_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          primary_teacher_id = excluded.primary_teacher_id,
          synced_at = excluded.synced_at;
      ''');
      for (final c in classes) {
        stmt.execute([
          c['id'] as String,
          c['name'] as String,
          c['primary_teacher_id'] as String?,
          now,
        ]);
      }
      stmt.dispose();
      database.execute('COMMIT;');
    } catch (_) {
      database.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Retrieves locally cached classes.
  List<Map<String, dynamic>> getCachedClasses() {
    final ResultSet results = database.select('SELECT * FROM cached_classes ORDER BY name ASC;');
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Caches students locally for offline lookup.
  void cacheStudents(List<Map<String, dynamic>> students) {
    final now = DateTime.now().toIso8601String();
    database.execute('BEGIN TRANSACTION;');
    try {
      final stmt = database.prepare('''
        INSERT INTO cached_students (id, name, roll_no, class_id, synced_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          roll_no = excluded.roll_no,
          class_id = excluded.class_id,
          synced_at = excluded.synced_at;
      ''');
      for (final s in students) {
        stmt.execute([
          s['id'] as String,
          s['name'] as String,
          s['roll_no']?.toString() ?? '',
          s['class_id'] as String,
          now,
        ]);
      }
      stmt.dispose();
      database.execute('COMMIT;');
    } catch (_) {
      database.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Retrieves cached students for a specific class.
  List<Map<String, dynamic>> getCachedStudents(String classId) {
    final stmt = database.prepare('''
      SELECT id, name, roll_no, class_id FROM cached_students
      WHERE class_id = ?
      ORDER BY roll_no ASC;
    ''');
    final ResultSet results = stmt.select([classId]);
    stmt.dispose();
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  // ============================================================
  // CACHE OPERATIONS: ATTENDANCE
  // ============================================================

  /// Caches attendance records locally.
  void cacheAttendance(List<Map<String, dynamic>> records) {
    final now = DateTime.now().toIso8601String();
    database.execute('BEGIN TRANSACTION;');
    try {
      final stmt = database.prepare('''
        INSERT INTO cached_attendance (
          id, student_id, class_id, date, session, status, marked_by, is_substitute, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(student_id, date, session) DO UPDATE SET
          status = excluded.status,
          marked_by = excluded.marked_by,
          is_substitute = excluded.is_substitute,
          updated_at = excluded.updated_at;
      ''');
      for (final r in records) {
        stmt.execute([
          r['id'] as String,
          r['student_id'] as String,
          r['class_id'] as String,
          r['date'] as String,
          r['session'] as String,
          r['status'] as String,
          r['marked_by'] as String,
          (r['is_substitute'] == true || r['is_substitute'] == 1) ? 1 : 0,
          now,
        ]);
      }
      stmt.dispose();
      database.execute('COMMIT;');
    } catch (_) {
      database.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Retrieves cached attendance for class, date, and session.
  List<Map<String, dynamic>> getCachedAttendance({
    required String classId,
    required String date,
    required String session,
  }) {
    final stmt = database.prepare('''
      SELECT * FROM cached_attendance
      WHERE class_id = ? AND date = ? AND session = ?;
    ''');
    final ResultSet results = stmt.select([classId, date, session]);
    stmt.dispose();
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  // ============================================================
  // TEACHER ATTENDANCE OPERATIONS
  // ============================================================

  /// Upserts a teacher attendance record in local SQLite.
  void upsertTeacherAttendance({
    required String id,
    required String teacherId,
    required String date,
    required String session,
    required String status,
    required String markedBy,
    required String updatedAt,
  }) {
    final stmt = database.prepare('''
      INSERT INTO teacher_attendance (id, teacher_id, date, session, status, marked_by, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(teacher_id, date, session) DO UPDATE SET
        id = excluded.id,
        status = excluded.status,
        marked_by = excluded.marked_by,
        updated_at = excluded.updated_at;
    ''');
    stmt.execute([id, teacherId, date, session, status, markedBy, updatedAt]);
    stmt.dispose();
  }

  /// Retrieves teacher attendance for a specific date and session.
  List<Map<String, dynamic>> getTeacherAttendance({
    required String date,
    required String session,
  }) {
    final stmt = database.prepare('''
      SELECT * FROM teacher_attendance
      WHERE date = ? AND session = ?;
    ''');
    final ResultSet results = stmt.select([date, session]);
    stmt.dispose();
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Closes database connection.
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
