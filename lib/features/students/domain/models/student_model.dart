/// Domain model representing a student from the `students` table.
class StudentModel {
  final String id;
  final String name;
  final String rollNo;
  final String classId;
  final String? className;
  final bool isActive;
  final DateTime? createdAt;

  const StudentModel({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.classId,
    this.className,
    this.isActive = true,
    this.createdAt,
  });

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    String? cName;
    if (map['classes'] is Map) {
      cName = map['classes']['name'] as String?;
    }

    return StudentModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      rollNo: map['roll_no'] as String? ?? '',
      classId: map['class_id'] as String,
      className: cName,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'roll_no': rollNo,
      'class_id': classId,
      'is_active': isActive,
    };
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? rollNo,
    String? classId,
    String? className,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
