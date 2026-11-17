import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/classes/domain/models/class_model.dart';

/// Repository for Class CRUD operations.
class ClassRepository {
  final SupabaseClient _supabase;

  ClassRepository(this._supabase);

  /// Fetches all classes with their assigned primary teacher's name
  /// and the active student count.
  Future<List<ClassModel>> getClasses() async {
    final response = await _supabase
        .from(AppConstants.tableClasses)
        .select('''
          id,
          name,
          primary_teacher_id,
          created_at,
          profiles:primary_teacher_id ( name ),
          students ( id )
        ''')
        .order('name', ascending: true);

    return (response as List)
        .map((row) => ClassModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new class.
  Future<void> createClass({
    required String name,
    String? primaryTeacherId,
  }) async {
    await _supabase.from(AppConstants.tableClasses).insert({
      'name': name.trim(),
      'primary_teacher_id': primaryTeacherId,
    });
  }

  /// Updates an existing class's name and primary teacher.
  Future<void> updateClass({
    required String id,
    required String name,
    String? primaryTeacherId,
  }) async {
    await _supabase
        .from(AppConstants.tableClasses)
        .update({
          'name': name.trim(),
          'primary_teacher_id': primaryTeacherId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Deletes a class.
  Future<void> deleteClass(String id) async {
    await _supabase.from(AppConstants.tableClasses).delete().eq('id', id);
  }
}
