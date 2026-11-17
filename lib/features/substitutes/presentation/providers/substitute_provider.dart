import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/substitutes/data/repositories/substitute_repository.dart';
import 'package:slkc_app/features/substitutes/domain/models/substitute_assignment_model.dart';

/// Provides [SubstituteRepository].
final substituteRepositoryProvider = Provider<SubstituteRepository>((ref) {
  return SubstituteRepository(SupabaseConfig.client);
});

/// Async notifier managing the list of substitute assignments.
class SubstitutesNotifier
    extends AsyncNotifier<List<SubstituteAssignmentModel>> {
  late final SubstituteRepository _repo;

  @override
  FutureOr<List<SubstituteAssignmentModel>> build() {
    _repo = ref.watch(substituteRepositoryProvider);
    return _repo.getSubstitutes();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getSubstitutes());
  }

  Future<void> createAssignment({
    required String classId,
    required String teacherId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _repo.createSubstituteAssignment(
      classId: classId,
      teacherId: teacherId,
      startDate: startDate,
      endDate: endDate,
    );
    await refresh();
  }

  Future<void> updateAssignment({
    required String id,
    required String classId,
    required String teacherId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _repo.updateSubstituteAssignment(
      id: id,
      classId: classId,
      teacherId: teacherId,
      startDate: startDate,
      endDate: endDate,
    );
    await refresh();
  }

  Future<void> deleteAssignment(String id) async {
    await _repo.deleteSubstituteAssignment(id);
    await refresh();
  }
}

final substitutesNotifierProvider =
    AsyncNotifierProvider<SubstitutesNotifier, List<SubstituteAssignmentModel>>(
  SubstitutesNotifier.new,
);

/// Provider returning active substitute assignments for the logged-in teacher today.
final teacherActiveSubstitutesProvider =
    FutureProvider<List<SubstituteAssignmentModel>>((ref) async {
  final repo = ref.watch(substituteRepositoryProvider);
  return repo.getTeacherActiveSubstitutesToday();
});

/// Set of class IDs where the logged-in teacher is actively assigned as substitute today.
final teacherSubstituteClassIdsProvider = Provider<Set<String>>((ref) {
  final activeAsync = ref.watch(teacherActiveSubstitutesProvider);
  return activeAsync.maybeWhen(
    data: (list) => list.map((a) => a.classId).toSet(),
    orElse: () => {},
  );
});
