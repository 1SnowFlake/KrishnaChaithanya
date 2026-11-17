import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/teachers/domain/models/teacher_model.dart';

/// Repository responsible for Teacher and Staff CRUD operations.
/// Creation is routed through the `create-teacher` Supabase Edge Function
/// because regular clients do not possess the `service_role` key required
/// to provision Auth accounts.
class TeacherRepository {
  final SupabaseClient _supabase;

  TeacherRepository(this._supabase);

  /// Fetches all teachers and staff ordered alphabetically by name.
  Future<List<TeacherModel>> getTeachers() async {
    final response = await _supabase
        .from(AppConstants.tableProfiles)
        .select()
        .order('name', ascending: true);

    return (response as List)
        .map((row) => TeacherModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new staff/teacher auth user and profile.
  ///
  /// The `create-teacher` Edge Function is preferred: it provisions the Auth
  /// account with the service_role key and confirms the email immediately.
  /// A direct signup is used only when the function is not deployed (404).
  /// Every other failure is a real error and is surfaced to the caller.
  Future<void> createTeacher({
    required String name,
    required String email,
    required String password,
    String role = StaffRoles.teacher,
  }) async {
    final trimmedRole = role.trim();
    // Normalize standard roles to lowercase to stay compatible with base schema constraint
    // CHECK (role IN ('admin', 'teacher')) even before migration 007 is executed.
    final normalizedRole = (trimmedRole.toLowerCase() == 'teacher')
        ? 'teacher'
        : (trimmedRole.toLowerCase() == 'admin')
            ? 'admin'
            : trimmedRole;

    try {
      await _supabase.functions.invoke(
        AppConstants.fnCreateTeacher,
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'role': normalizedRole,
        },
      );
      return;
    } on FunctionException catch (e) {
      if (e.status != 404) {
        throw Exception(_functionErrorMessage(e));
      }
    } catch (e) {
      throw Exception('Could not reach the create-teacher function: $e');
    }

    await _signUpDirectly(
      name: name,
      email: email,
      password: password,
      role: normalizedRole,
    );
  }

  String _functionErrorMessage(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    return e.reasonPhrase ?? 'Failed to create staff account (${e.status}).';
  }

  /// Fallback used only when the Edge Function is missing.
  /// The profile row, including its role, is created by the
  /// `handle_new_user` trigger from the metadata passed here.
  Future<void> _signUpDirectly({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final isolatedClient = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );

    try {
      final res = await isolatedClient.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
          'role': role.trim(),
        },
      );
      if (res.user == null) {
        throw Exception('Could not create the staff account.');
      }
    } finally {
      await isolatedClient.dispose();
    }
  }

  /// Updates an existing staff's name, active status, and optional role.
  Future<void> updateTeacher({
    required String id,
    required String name,
    required bool isActive,
    String? role,
  }) async {
    final updateData = <String, dynamic>{
      'name': name.trim(),
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (role != null) {
      updateData['role'] = role.trim();
    }

    try {
      await _supabase
          .from(AppConstants.tableProfiles)
          .update(updateData)
          .eq('id', id);
    } catch (e) {
      // If check constraint profiles_role_check fails on remote Supabase, fallback safely
      if (e.toString().contains('profiles_role_check') ||
          e.toString().contains('23514')) {
        updateData['role'] =
            role?.toLowerCase() == 'admin' ? 'admin' : 'teacher';
        await _supabase
            .from(AppConstants.tableProfiles)
            .update(updateData)
            .eq('id', id);
      } else {
        rethrow;
      }
    }
  }

  /// Toggles active/inactive status for a teacher.
  Future<void> toggleTeacherStatus(String id, bool newStatus) async {
    await _supabase
        .from(AppConstants.tableProfiles)
        .update({
          'is_active': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Promotes or demotes a teacher's role ('admin' vs 'teacher').
  Future<void> updateTeacherRole(String id, String newRole) async {
    await _supabase
        .from(AppConstants.tableProfiles)
        .update({
          'role': newRole,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Deletes a teacher profile permanently.
  Future<void> deleteTeacher(String id) async {
    await _supabase
        .from(AppConstants.tableProfiles)
        .delete()
        .eq('id', id);
  }
}
