import 'package:slkc_app/core/constants/app_constants.dart';

/// Represents a user profile from the `profiles` table.
/// Every authenticated user has an entry linked by their user ID.
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// True if the user has admin privileges.
  bool get isAdmin => role.toLowerCase() == AppConstants.roleAdmin;

  /// True if the user is a teacher or non-admin staff member.
  bool get isTeacher => !isAdmin;

  /// Creates a UserProfile from a Supabase row map.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? AppConstants.roleTeacher,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  /// Converts this profile instance to a database-friendly map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          role == other.role &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^ email.hashCode ^ role.hashCode ^ isActive.hashCode;
}
