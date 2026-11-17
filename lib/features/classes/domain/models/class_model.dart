/// Domain model representing a school class/section from the `classes` table.
class ClassModel {
  final String id;
  final String name;
  final String? primaryTeacherId;
  final String? primaryTeacherName;
  final int studentCount;
  final DateTime? createdAt;

  const ClassModel({
    required this.id,
    required this.name,
    this.primaryTeacherId,
    this.primaryTeacherName,
    this.studentCount = 0,
    this.createdAt,
  });

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    // When joining with profiles for primary_teacher_id:
    String? teacherName;
    if (map['profiles'] is Map) {
      teacherName = map['profiles']['name'] as String?;
    }

    // When counting students:
    int count = 0;
    if (map['students'] is List) {
      count = (map['students'] as List).length;
    } else if (map['student_count'] is int) {
      count = map['student_count'] as int;
    }

    return ClassModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unnamed Class',
      primaryTeacherId: map['primary_teacher_id'] as String?,
      primaryTeacherName: teacherName,
      studentCount: count,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'primary_teacher_id': primaryTeacherId,
    };
  }

  ClassModel copyWith({
    String? id,
    String? name,
    String? primaryTeacherId,
    String? primaryTeacherName,
    int? studentCount,
    DateTime? createdAt,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryTeacherId: primaryTeacherId ?? this.primaryTeacherId,
      primaryTeacherName: primaryTeacherName ?? this.primaryTeacherName,
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
