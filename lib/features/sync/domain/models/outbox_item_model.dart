/// Represents an attendance entry queued locally in SQLite for synchronization.
class OutboxItemModel {
  final String id;
  final String studentId;
  final String classId;
  final String date; // yyyy-MM-dd
  final String session; // 'morning' or 'afternoon'
  final String status; // 'present' or 'absent'
  final String markedBy;
  final bool isSubstitute;
  final DateTime createdAt;
  final String syncStatus; // 'pending', 'syncing', 'synced', 'failed'
  final String? errorMessage;
  final int retryCount;

  const OutboxItemModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.date,
    required this.session,
    required this.status,
    required this.markedBy,
    this.isSubstitute = false,
    required this.createdAt,
    this.syncStatus = 'pending',
    this.errorMessage,
    this.retryCount = 0,
  });

  bool get isPending => syncStatus == 'pending';
  bool get isFailed => syncStatus == 'failed';
  bool get isSynced => syncStatus == 'synced';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'class_id': classId,
      'date': date,
      'session': session,
      'status': status,
      'marked_by': markedBy,
      'is_substitute': isSubstitute ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus,
      'error_message': errorMessage,
      'retry_count': retryCount,
    };
  }

  factory OutboxItemModel.fromMap(Map<String, dynamic> map) {
    return OutboxItemModel(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      classId: map['class_id'] as String,
      date: map['date'] as String,
      session: map['session'] as String,
      status: map['status'] as String,
      markedBy: map['marked_by'] as String,
      isSubstitute: (map['is_substitute'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
      errorMessage: map['error_message'] as String?,
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  OutboxItemModel copyWith({
    String? syncStatus,
    String? errorMessage,
    int? retryCount,
  }) {
    return OutboxItemModel(
      id: id,
      studentId: studentId,
      classId: classId,
      date: date,
      session: session,
      status: status,
      markedBy: markedBy,
      isSubstitute: isSubstitute,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
