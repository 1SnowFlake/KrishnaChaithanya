import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/classes/data/repositories/class_repository.dart';
import 'package:slkc_app/features/classes/domain/models/class_model.dart';

/// Provides the [ClassRepository] instance.
final classRepositoryProvider = Provider<ClassRepository>((ref) {
  return ClassRepository(SupabaseConfig.client);
});

/// Async notifier managing the list of classes in the system.
class ClassesNotifier extends AsyncNotifier<List<ClassModel>> {
  late final ClassRepository _repo;

  @override
  FutureOr<List<ClassModel>> build() {
    _repo = ref.watch(classRepositoryProvider);
    return _repo.getClasses();
  }

  /// Reloads all classes.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getClasses());
  }

  /// Adds a new class.
  Future<void> createClass({
    required String name,
    String? primaryTeacherId,
  }) async {
    await _repo.createClass(name: name, primaryTeacherId: primaryTeacherId);
    await refresh();
  }

  /// Updates an existing class.
  Future<void> updateClass({
    required String id,
    required String name,
    String? primaryTeacherId,
  }) async {
    await _repo.updateClass(
      id: id,
      name: name,
      primaryTeacherId: primaryTeacherId,
    );
    await refresh();
  }

  /// Deletes a class.
  Future<void> deleteClass(String id) async {
    await _repo.deleteClass(id);
    await refresh();
  }
}

final classesNotifierProvider =
    AsyncNotifierProvider<ClassesNotifier, List<ClassModel>>(
  ClassesNotifier.new,
);

/// Convenient alias for classesNotifierProvider
final classesProvider = classesNotifierProvider;
