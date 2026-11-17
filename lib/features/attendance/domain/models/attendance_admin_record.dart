/// Represents a student attendance record from the perspective of an Administrator.
/// Can represent an existing record or an unmarked slot for a student on a specific date/session.
class AttendanceAdminRecord {
  final String studentId;
  final String studentName;
  final String rollNo;
  final String classId;
  final String date; // YYYY-MM-DD
  final String session; // 'morning' | 'afternoon'
  final String? attendanceId; // Null if not yet marked
  final String? status; // 'present' | 'absent' | null
  final String? markedBy;
  final String? markedByName;
  final DateTime? updatedAt;

  const AttendanceAdminRecord({
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.classId,
    required this.date,
    required this.session,
    this.attendanceId,
    this.status,
    this.markedBy,
    this.markedByName,
    this.updatedAt,
  });

  bool get isMarked => status != null && status!.isNotEmpty;
  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';

  AttendanceAdminRecord copyWith({
    String? studentId,
    String? studentName,
    String? rollNo,
    String? classId,
    String? date,
    String? session,
    String? attendanceId,
    String? status,
    String? markedBy,
    String? markedByName,
    DateTime? updatedAt,
  }) {
    return AttendanceAdminRecord(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      rollNo: rollNo ?? this.rollNo,
      classId: classId ?? this.classId,
      date: date ?? this.date,
      session: session ?? this.session,
      attendanceId: attendanceId ?? this.attendanceId,
      status: status ?? this.status,
      markedBy: markedBy ?? this.markedBy,
      markedByName: markedByName ?? this.markedByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
