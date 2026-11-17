import 'package:slkc_app/core/constants/app_constants.dart';

/// Domain model representing a single student attendance record.
/// Enforces status constraint: strictly 'present' or 'absent'.
class AttendanceModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? studentRollNo;
  final String classId;
  final DateTime date;
  final String session; // 'morning' | 'afternoon'
  final String status;  // 'present' | 'absent'
  final String markedBy;
  final bool isSubstitute;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AttendanceModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.studentRollNo,
    required this.classId,
    required this.date,
    required this.session,
    required this.status,
    required this.markedBy,
    this.isSubstitute = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPresent => status == AppConstants.statusPresent;
  bool get isAbsent => status == AppConstants.statusAbsent;

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    String? sName;
    String? sRoll;
    if (map['students'] is Map) {
      sName = map['students']['name'] as String?;
      sRoll = map['students']['roll_no'] as String?;
    }

    return AttendanceModel(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      studentName: sName,
      studentRollNo: sRoll,
      classId: map['class_id'] as String,
      date: DateTime.parse(map['date'] as String),
      session: map['session'] as String,
      status: map['status'] as String,
      markedBy: map['marked_by'] as String,
      isSubstitute: map['is_substitute'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'class_id': classId,
      'date': date.toIso8601String().split('T')[0],
      'session': session,
      'status': status,
      'marked_by': markedBy,
      'is_substitute': isSubstitute,
    };
  }
}
