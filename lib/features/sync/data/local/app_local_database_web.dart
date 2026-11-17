import '../../domain/models/outbox_item_model.dart';

/// Web-compatible local database handling offline attendance outbox queue and local cached data
/// for Flutter Web (Chrome, Edge, Firefox, Safari) without any native FFI / SQLite dependencies.
class AppLocalDatabase {
  final Map<String, String> _preferences = {};
  final Map<String, OutboxItemModel> _outbox = {};
  final Map<String, Map<String, dynamic>> _cachedClasses = {};
  final List<Map<String, dynamic>> _cachedStudents = [];
  final Map<String, Map<String, dynamic>> _cachedAttendance = {};
  final Map<String, Map<String, dynamic>> _teacherAttendance = {};

  AppLocalDatabase([dynamic _]);

  /// Initializes the Web in-memory local database.
  Future<void> init({bool inMemory = false}) async {
    // In-memory web storage initialized
  }

  // ============================================================
  // PREFERENCE OPERATIONS
  // ============================================================

  /// Sets a persistent key-value preference.
  void setPreference(String key, String value) {
    _preferences[key] = value;
  }

  /// Retrieves a persistent key-value preference.
  String? getPreference(String key) {
    return _preferences[key];
  }

  // ============================================================
  // OUTBOX OPERATIONS
  // ============================================================

  /// Adds or updates an attendance record in the outbox queue.
  void queueAttendance(OutboxItemModel item) {
    final key = '${item.studentId}_${item.date}_${item.session}';
    _outbox[key] = item.copyWith(
      syncStatus: 'pending',
      errorMessage: null,
    );
  }

  /// Queues a batch of attendance records.
  void queueBatchAttendance(List<OutboxItemModel> items) {
    for (final item in items) {
      queueAttendance(item);
    }
  }

  /// Retrieves all outbox records waiting to sync (pending or failed).
  List<OutboxItemModel> getPendingOutboxItems() {
    final list = _outbox.values
        .where((item) => item.syncStatus == 'pending' || item.syncStatus == 'failed')
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Returns the count of pending outbox records.
  int getPendingOutboxCount() {
    return _outbox.values
        .where((item) => item.syncStatus == 'pending' || item.syncStatus == 'failed')
        .length;
  }

  /// Updates status of an outbox item.
  void updateOutboxStatus(
    String id,
    String status, {
    String? errorMessage,
    int? retryCount,
  }) {
    for (final entry in _outbox.entries) {
      if (entry.value.id == id) {
        _outbox[entry.key] = entry.value.copyWith(
          syncStatus: status,
          errorMessage: errorMessage,
          retryCount: retryCount ?? entry.value.retryCount,
        );
        break;
      }
    }
  }

  /// Deletes a specific item from the outbox.
  void deleteOutboxItem(String id) {
    _outbox.removeWhere((key, value) => value.id == id);
  }

  /// Cleans up synced items.
  void clearSyncedOutbox() {
    _outbox.removeWhere((key, value) => value.syncStatus == 'synced');
  }

  // ============================================================
  // CACHE OPERATIONS: CLASSES & STUDENTS
  // ============================================================

  /// Caches classes locally for offline lookup.
  void cacheClasses(List<Map<String, dynamic>> classes) {
    for (final c in classes) {
      final id = c['id'] as String;
      _cachedClasses[id] = Map<String, dynamic>.from(c);
    }
  }

  /// Retrieves locally cached classes.
  List<Map<String, dynamic>> getCachedClasses() {
    final list = _cachedClasses.values.toList();
    list.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
    return list;
  }

  /// Caches students locally for offline lookup.
  void cacheStudents(List<Map<String, dynamic>> students) {
    for (final s in students) {
      final id = s['id'] as String;
      _cachedStudents.removeWhere((existing) => existing['id'] == id);
      _cachedStudents.add(Map<String, dynamic>.from(s));
    }
  }

  /// Retrieves cached students for a specific class.
  List<Map<String, dynamic>> getCachedStudents(String classId) {
    final list = _cachedStudents.where((s) => s['class_id'] == classId).toList();
    list.sort((a, b) {
      final aRoll = int.tryParse(a['roll_no']?.toString() ?? '');
      final bRoll = int.tryParse(b['roll_no']?.toString() ?? '');
      if (aRoll != null && bRoll != null) return aRoll.compareTo(bRoll);
      return (a['roll_no']?.toString() ?? '').compareTo(b['roll_no']?.toString() ?? '');
    });
    return list;
  }

  // ============================================================
  // CACHE OPERATIONS: ATTENDANCE
  // ============================================================

  /// Caches attendance records locally.
  void cacheAttendance(List<Map<String, dynamic>> records) {
    for (final r in records) {
      final key = '${r['student_id']}_${r['date']}_${r['session']}';
      _cachedAttendance[key] = Map<String, dynamic>.from(r);
    }
  }

  /// Retrieves cached attendance for class, date, and session.
  List<Map<String, dynamic>> getCachedAttendance({
    required String classId,
    required String date,
    required String session,
  }) {
    return _cachedAttendance.values.where((r) {
      return r['class_id'] == classId && r['date'] == date && r['session'] == session;
    }).toList();
  }

  // ============================================================
  // TEACHER ATTENDANCE OPERATIONS
  // ============================================================

  /// Upserts a teacher attendance record in memory.
  void upsertTeacherAttendance({
    required String id,
    required String teacherId,
    required String date,
    required String session,
    required String status,
    required String markedBy,
    required String updatedAt,
  }) {
    final key = '${teacherId}_${date}_$session';
    _teacherAttendance[key] = {
      'id': id,
      'teacher_id': teacherId,
      'date': date,
      'session': session,
      'status': status,
      'marked_by': markedBy,
      'updated_at': updatedAt,
    };
  }

  /// Retrieves teacher attendance for a specific date and session.
  List<Map<String, dynamic>> getTeacherAttendance({
    required String date,
    required String session,
  }) {
    return _teacherAttendance.values.where((r) {
      return r['date'] == date && r['session'] == session;
    }).toList();
  }

  /// Closes database connection.
  void dispose() {
    _preferences.clear();
    _outbox.clear();
    _cachedClasses.clear();
    _cachedStudents.clear();
    _cachedAttendance.clear();
    _teacherAttendance.clear();
  }
}
