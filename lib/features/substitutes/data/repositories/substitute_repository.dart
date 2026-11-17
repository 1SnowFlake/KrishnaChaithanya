import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/substitutes/domain/models/substitute_assignment_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for querying and mutating substitute teacher assignments in Supabase.
class SubstituteRepository {
  final SupabaseClient _supabase;

  SubstituteRepository(this._supabase);

  /// Fetches substitute assignments with joined class and teacher profile info.
  Future<List<SubstituteAssignmentModel>> getSubstitutes({
    String? classId,
    String? teacherId,
  }) async {
    var query = _supabase.from(AppConstants.tableSubstitutes).select('''
      id,
      class_id,
      teacher_id,
      start_date,
      end_date,
      created_at,
      classes:class_id ( name ),
      profiles:teacher_id ( name, email )
    ''');

    if (classId != null && classId.isNotEmpty) {
      query = query.eq('class_id', classId);
    }
    if (teacherId != null && teacherId.isNotEmpty) {
      query = query.eq('teacher_id', teacherId);
    }

    final response = await query.order('start_date', ascending: false);
    final list = (response as List).cast<Map<String, dynamic>>();

    return list.map((item) => SubstituteAssignmentModel.fromMap(item)).toList();
  }

  /// Creates a new substitute assignment (Admin only via RLS).
  Future<SubstituteAssignmentModel> createSubstituteAssignment({
    required String classId,
    required String teacherId,
    required DateTime startDate,
    required DateTime endDate,
    String? createdBy,
  }) async {
    final user = _supabase.auth.currentUser;
    final adminId = createdBy ?? user?.id;
    if (adminId == null) throw Exception('No authenticated user to record created_by');

    final fmt = DateFormat('yyyy-MM-dd');
    final response = await _supabase
        .from(AppConstants.tableSubstitutes)
        .insert({
          'class_id': classId,
          'teacher_id': teacherId,
          'start_date': fmt.format(startDate),
          'end_date': fmt.format(endDate),
          'created_by': adminId,
        })
        .select('''
          id,
          class_id,
          teacher_id,
          start_date,
          end_date,
          created_at,
          classes:class_id ( name ),
          profiles:teacher_id ( name, email )
        ''')
        .single();

    return SubstituteAssignmentModel.fromMap(response);
  }

  /// Updates an existing substitute assignment.
  Future<void> updateSubstituteAssignment({
    required String id,
    required String classId,
    required String teacherId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    await _supabase
        .from(AppConstants.tableSubstitutes)
        .update({
          'class_id': classId,
          'teacher_id': teacherId,
          'start_date': fmt.format(startDate),
          'end_date': fmt.format(endDate),
        })
        .eq('id', id);
  }

  /// Deletes a substitute assignment.
  Future<void> deleteSubstituteAssignment(String id) async {
    await _supabase
        .from(AppConstants.tableSubstitutes)
        .delete()
        .eq('id', id);
  }

  /// Fetches active substitute assignments for the currently logged in teacher today.
  Future<List<SubstituteAssignmentModel>> getTeacherActiveSubstitutesToday() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await _supabase
        .from(AppConstants.tableSubstitutes)
        .select('''
          id,
          class_id,
          teacher_id,
          start_date,
          end_date,
          created_at,
          classes:class_id ( name ),
          profiles:teacher_id ( name, email )
        ''')
        .eq('teacher_id', user.id)
        .lte('start_date', todayStr)
        .gte('end_date', todayStr);

    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map((item) => SubstituteAssignmentModel.fromMap(item)).toList();
  }
}
