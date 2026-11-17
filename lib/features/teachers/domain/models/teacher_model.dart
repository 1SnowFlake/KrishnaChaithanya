import 'package:slkc_app/core/constants/app_constants.dart';

/// Domain model representing a teacher/staff profile from the `profiles` table.
class TeacherModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'teacher' | 'admin'
  final bool isActive;
  final DateTime? createdAt;

  const TeacherModel({
    required this.id,
    required this.name,
    required this.email,
    this.role = AppConstants.roleTeacher,
    required this.isActive,
    this.createdAt,
  });

  bool get isAdmin => role.toLowerCase() == AppConstants.roleAdmin;

  factory TeacherModel.fromMap(Map<String, dynamic> map) {
    return TeacherModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unnamed Teacher',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? AppConstants.roleTeacher,
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
      'email': email,
      'role': role,
      'is_active': isActive,
    };
  }

  TeacherModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return TeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
