import 'package:intl/intl.dart';

/// Domain model representing an in-app alert or notification.
/// Matches Supabase table: `id`, `user_id`, `type`, `message`, `is_read`, `metadata`, `created_at`.
class NotificationModel {
  final String id;
  final String? userId; // null means broadcast to all administrators
  final String type;
  final String message;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    this.userId,
    required this.type,
    required this.message,
    this.isRead = false,
    this.metadata,
    required this.createdAt,
  });

  /// True if this notification is broadcast to all administrators.
  bool get isBroadcast => userId == null || userId!.isEmpty;

  /// Derived title for UI rendering.
  String get title {
    if (metadata != null && metadata!['title'] != null) {
      return metadata!['title'] as String;
    }
    switch (type) {
      case 'missing_attendance':
        return 'Missing Attendance Alert';
      case 'low_attendance':
        return 'Low Attendance Warning';
      case 'system':
        return 'System Announcement';
      default:
        return 'School Notification';
    }
  }

  /// Returns a clean relative or formatted timestamp.
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && now.day == createdAt.day) {
      return 'Today, ${DateFormat('h:mm a').format(createdAt)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('d MMM yyyy, h:mm a').format(createdAt);
    }
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String?,
      type: map['type'] as String? ?? 'missing_attendance',
      message: map['message'] as String? ?? '',
      isRead: map['is_read'] as bool? ?? false,
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'type': type,
      'message': message,
      'is_read': isRead,
      'metadata': metadata,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? message,
    bool? isRead,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
