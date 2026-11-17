/// Represents an audit trail entry recorded when attendance is inserted or updated.
class AttendanceLogModel {
  final String id;
  final String attendanceId;
  final String studentName;
  final String rollNo;
  final String className;
  final String date;
  final String session;
  final String? oldStatus;
  final String newStatus;
  final String changedByName;
  final String changedByEmail;
  final String changedByRole;
  final DateTime changedAt;

  const AttendanceLogModel({
    required this.id,
    required this.attendanceId,
    required this.studentName,
    required this.rollNo,
    required this.className,
    required this.date,
    required this.session,
    this.oldStatus,
    required this.newStatus,
    required this.changedByName,
    required this.changedByEmail,
    required this.changedByRole,
    required this.changedAt,
  });

  bool get isInitialMark => oldStatus == null || oldStatus!.isEmpty;

  factory AttendanceLogModel.fromJson(Map<String, dynamic> json) {
    // Supabase joined structure:
    // attendance: { date, session, students(name, roll_no), classes(name) }
    // profiles: { name, email, role }
    final attendanceData = json['attendance'] as Map<String, dynamic>? ?? {};
    final studentData = attendanceData['students'] as Map<String, dynamic>? ?? {};
    final classData = attendanceData['classes'] as Map<String, dynamic>? ?? {};
    final profileData = json['profiles'] as Map<String, dynamic>? ?? {};

    return AttendanceLogModel(
      id: json['id'] as String? ?? '',
      attendanceId: json['attendance_id'] as String? ?? '',
      studentName: studentData['name'] as String? ?? 'Unknown Student',
      rollNo: studentData['roll_no'] as String? ?? '-',
      className: classData['name'] as String? ?? 'Unknown Class',
      date: attendanceData['date'] as String? ?? '',
      session: attendanceData['session'] as String? ?? '',
      oldStatus: json['old_status'] as String?,
      newStatus: json['new_status'] as String? ?? 'present',
      changedByName: profileData['name'] as String? ?? 'System',
      changedByEmail: profileData['email'] as String? ?? '',
      changedByRole: profileData['role'] as String? ?? 'teacher',
      changedAt: json['changed_at'] != null
          ? DateTime.parse(json['changed_at'] as String).toLocal()
          : DateTime.now(),
    );
  }
}
