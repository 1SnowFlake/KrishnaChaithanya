import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/teachers/data/repositories/teacher_repository.dart';
import 'package:slkc_app/features/teachers/domain/models/teacher_model.dart';

/// Provides the [TeacherRepository] instance.
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepository(SupabaseConfig.client);
});

/// Async notifier managing the list of all teachers and staff for the Admin dashboard.
class TeachersNotifier extends AsyncNotifier<List<TeacherModel>> {
  late final TeacherRepository _repo;

  @override
  FutureOr<List<TeacherModel>> build() {
    _repo = ref.watch(teacherRepositoryProvider);
    return _repo.getTeachers();
  }

  /// Reloads the teacher list from the database.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getTeachers());
  }

  /// Provisions a new staff/teacher via Edge Function or direct signup and refreshes the list.
  Future<void> createTeacher({
    required String name,
    required String email,
    required String password,
    String role = StaffRoles.teacher,
  }) async {
    await _repo.createTeacher(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    await refresh();
  }

  /// Updates teacher details including role and active status.
  Future<void> updateTeacher({
    required String id,
    required String name,
    required bool isActive,
    String? role,
  }) async {
    await _repo.updateTeacher(
      id: id,
      name: name,
      isActive: isActive,
      role: role,
    );
    await refresh();
  }

  /// Toggles a teacher's active state.
  Future<void> toggleStatus(String id, bool newStatus) async {
    await _repo.toggleTeacherStatus(id, newStatus);
    await refresh();
  }

  /// Updates a teacher's role ('admin' vs 'teacher').
  Future<void> updateRole(String id, String newRole) async {
    await _repo.updateTeacherRole(id, newRole);
    await refresh();
  }

  /// Deletes a teacher permanently.
  Future<void> deleteTeacher(String id) async {
    try {
      await _repo.deleteTeacher(id);
      await refresh();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('foreign key') || msg.contains('violates foreign key')) {
        throw Exception(
          'Cannot delete this teacher because they have recorded attendance history. '
          'Please deactivate their account instead.',
        );
      }
      rethrow;
    }
  }
}

final teachersNotifierProvider =
    AsyncNotifierProvider<TeachersNotifier, List<TeacherModel>>(
  TeachersNotifier.new,
);

/// Convenient alias for teachersNotifierProvider
final teachersProvider = teachersNotifierProvider;
