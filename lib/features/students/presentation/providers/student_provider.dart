import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/students/data/repositories/student_repository.dart';
import 'package:slkc_app/features/students/domain/models/student_model.dart';

/// Provides the [StudentRepository] instance.
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(SupabaseConfig.client);
});

/// Holds the currently selected class ID filter in the UI.
/// `null` means "All Classes".
final selectedClassFilterProvider = StateProvider<String?>((ref) => null);

/// Async notifier managing the student list, automatically re-fetching
/// whenever the [selectedClassFilterProvider] changes.
class StudentsNotifier extends AsyncNotifier<List<StudentModel>> {
  late final StudentRepository _repo;

  @override
  FutureOr<List<StudentModel>> build() {
    _repo = ref.watch(studentRepositoryProvider);
    final filterClassId = ref.watch(selectedClassFilterProvider);
    return _repo.getStudents(classId: filterClassId);
  }

  /// Explicitly changes the class filter and fetches the new list immediately.
  Future<void> filterByClass(String? classId) async {
    ref.read(selectedClassFilterProvider.notifier).state = classId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getStudents(classId: classId));
  }

  /// Reloads students according to the current filter.
  Future<void> refresh() async {
    final filterClassId = ref.read(selectedClassFilterProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getStudents(classId: filterClassId));
  }

  /// Adds a single student.
  Future<void> createStudent({
    required String name,
    required String rollNo,
    required String classId,
  }) async {
    await _repo.createStudent(name: name, rollNo: rollNo, classId: classId);
    await refresh();
  }

  /// Updates student info.
  Future<void> updateStudent({
    required String id,
    required String name,
    required String rollNo,
    required String classId,
    required bool isActive,
  }) async {
    await _repo.updateStudent(
      id: id,
      name: name,
      rollNo: rollNo,
      classId: classId,
      isActive: isActive,
    );
    await refresh();
  }

  /// Deletes a student.
  Future<void> deleteStudent(String id) async {
    await _repo.deleteStudent(id);
    await refresh();
  }

  /// Bulk imports students from a CSV string.
  Future<CsvImportResult> importFromCsv({
    required String classId,
    required String csvContent,
  }) async {
    final result = await _repo.importStudentsFromCsv(
      classId: classId,
      csvContent: csvContent,
    );
    await refresh();
    return result;
  }
}

final studentsNotifierProvider =
    AsyncNotifierProvider<StudentsNotifier, List<StudentModel>>(
  StudentsNotifier.new,
);
