import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/teaching_tools/domain/models/lesson_plan_model.dart';

/// Repository responsible for AI Teaching Tools generation and persistence.
class TeachingToolsRepository {
  final SupabaseClient _supabase;

  TeachingToolsRepository(this._supabase);

  /// Invokes the `generate-content` Supabase Edge Function to generate a Lesson Plan.
  Future<LessonPlanModel> generateLessonPlan({
    required String subject,
    required String topic,
    required String grade,
    required int durationMinutes,
    required String language,
    required List<String> learnerNeeds,
    String? learningObjectives,
    String? materialsAvailable,
    int? classSize,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        AppConstants.fnGenerateContent,
        body: {
          'type': AppConstants.contentTypeLessonPlan,
          'subject': subject.trim(),
          'topic': topic.trim(),
          'grade': grade.trim(),
          'durationMinutes': durationMinutes,
          'language': language.trim(),
          'learnerNeeds': learnerNeeds,
          if (learningObjectives != null && learningObjectives.trim().isNotEmpty)
            'learningObjectives': learningObjectives.trim(),
          if (materialsAvailable != null && materialsAvailable.trim().isNotEmpty)
            'materialsAvailable': materialsAvailable.trim(),
          'classSize': ?classSize,
        },
      );

      final data = response.data;
      if (data == null || data['content'] == null) {
        throw Exception('The AI generator returned an empty response. Please try again.');
      }

      final contentMap = data['content'] as Map<String, dynamic>;
      return LessonPlanModel.fromMap(contentMap);
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      if (e.status == 429) {
        throw Exception(
          'Daily generation limit reached. Free quotas reset at midnight. Please try again tomorrow.',
        );
      }
      throw Exception(e.reasonPhrase ?? 'AI generation failed (${e.status}).');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error during generation: $e');
    }
  }

  /// Saves a teaching item (Lesson Plan, Worksheet, Quiz) to the `ai_content` table.
  Future<String> saveContent({
    required String type,
    required String title,
    required String subject,
    required String grade,
    required String language,
    required List<String> learnerNeeds,
    required Map<String, dynamic> content,
    String? classId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to save teaching materials.');
    }

    final row = await _supabase.from(AppConstants.tableAiContent).insert({
      'type': type,
      'title': title.trim(),
      'subject': subject.trim(),
      'grade': grade.trim(),
      'language': language.trim(),
      'learner_needs': learnerNeeds,
      'content': content,
      'class_id': classId,
      'created_by': user.id,
      'is_shared': false,
    }).select('id').single();

    return row['id'] as String;
  }

  /// Updates an existing teaching item in the `ai_content` table.
  Future<void> updateContent({
    required String id,
    required String title,
    required Map<String, dynamic> content,
    String? classId,
    bool? isShared,
  }) async {
    final updateData = <String, dynamic>{
      'title': title.trim(),
      'content': content,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (classId != null) updateData['class_id'] = classId;
    if (isShared != null) updateData['is_shared'] = isShared;

    await _supabase
        .from(AppConstants.tableAiContent)
        .update(updateData)
        .eq('id', id);
  }

  /// Deletes a teaching item by its ID.
  Future<void> deleteContent(String id) async {
    await _supabase.from(AppConstants.tableAiContent).delete().eq('id', id);
  }
}
