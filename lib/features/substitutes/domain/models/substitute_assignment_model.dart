import 'package:intl/intl.dart';

/// Domain model representing a temporary substitute teacher assignment.
class SubstituteAssignmentModel {
  final String id;
  final String classId;
  final String className;
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? createdAt;

  const SubstituteAssignmentModel({
    required this.id,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.startDate,
    required this.endDate,
    this.createdAt,
  });

  /// Total number of days covered by this substitute assignment.
  int get dayCount => endDate.difference(startDate).inDays + 1;

  /// True if the assignment is only for a single calendar day.
  bool get isSingleDay =>
      startDate.year == endDate.year &&
      startDate.month == endDate.month &&
      startDate.day == endDate.day;

  /// True if today falls within the assignment date range.
  bool get isActiveToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isBefore(s) && !today.isAfter(e);
  }

  /// True if the assignment will become active in the future.
  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    return s.isAfter(today);
  }

  /// True if the assignment has passed.
  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return e.isBefore(today);
  }

  /// Human-readable date range format.
  String get formattedRange {
    final fmt = DateFormat('d MMM yyyy');
    if (isSingleDay) {
      return fmt.format(startDate);
    }
    return '${fmt.format(startDate)} – ${fmt.format(endDate)} ($dayCount days)';
  }

  factory SubstituteAssignmentModel.fromMap(Map<String, dynamic> map) {
    final classData = map['classes'] as Map<String, dynamic>? ?? {};
    final profileData = map['profiles'] as Map<String, dynamic>? ?? {};

    return SubstituteAssignmentModel(
      id: map['id'] as String? ?? '',
      classId: map['class_id'] as String? ?? '',
      className: classData['name'] as String? ?? 'Unknown Class',
      teacherId: map['teacher_id'] as String? ?? '',
      teacherName: profileData['name'] as String? ?? 'Unknown Teacher',
      teacherEmail: profileData['email'] as String? ?? '',
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final fmt = DateFormat('yyyy-MM-dd');
    return {
      'class_id': classId,
      'teacher_id': teacherId,
      'start_date': fmt.format(startDate),
      'end_date': fmt.format(endDate),
    };
  }

  SubstituteAssignmentModel copyWith({
    String? id,
    String? classId,
    String? className,
    String? teacherId,
    String? teacherName,
    String? teacherEmail,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return SubstituteAssignmentModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherEmail: teacherEmail ?? this.teacherEmail,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
