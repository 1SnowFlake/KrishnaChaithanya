import 'package:slkc_app/core/constants/app_constants.dart';

/// Represents a teacher's attendance record for a specific date and session.
class TeacherAttendanceModel {
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final String role;
  final String date; // YYYY-MM-DD
  final String session; // 'morning' | 'afternoon'
  final String? attendanceId;
  final String? status; // 'present' | 'absent' | null (unmarked)
  final String? markedBy;
  final String? markedByName;
  final DateTime? updatedAt;

  const TeacherAttendanceModel({
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.role,
    required this.date,
    required this.session,
    this.attendanceId,
    this.status,
    this.markedBy,
    this.markedByName,
    this.updatedAt,
  });

  bool get isPresent => status == AppConstants.statusPresent;
  bool get isAbsent => status == AppConstants.statusAbsent;
  bool get isMarked => status != null;

  TeacherAttendanceModel copyWith({
    String? attendanceId,
    String? status,
    String? markedBy,
    String? markedByName,
    DateTime? updatedAt,
  }) {
    return TeacherAttendanceModel(
      teacherId: teacherId,
      teacherName: teacherName,
      teacherEmail: teacherEmail,
      role: role,
      date: date,
      session: session,
      attendanceId: attendanceId ?? this.attendanceId,
      status: status ?? this.status,
      markedBy: markedBy ?? this.markedBy,
      markedByName: markedByName ?? this.markedByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacher_id': teacherId,
      'date': date,
      'session': session,
      'status': status,
      'marked_by': markedBy,
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}
