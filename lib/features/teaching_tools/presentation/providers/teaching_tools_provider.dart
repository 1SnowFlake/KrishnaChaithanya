import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/teaching_tools/data/repositories/teaching_tools_repository.dart';
import 'package:slkc_app/features/teaching_tools/domain/models/lesson_plan_model.dart';

/// Provides singleton instance of [TeachingToolsRepository].
final teachingToolsRepositoryProvider = Provider<TeachingToolsRepository>((ref) {
  return TeachingToolsRepository(SupabaseConfig.client);
});

/// State for the Lesson Plan generation flow.
class LessonPlanState {
  final bool isGenerating;
  final bool isSaving;
  final String? errorMessage;
  final LessonPlanModel? lessonPlan;
  final String? savedId;

  const LessonPlanState({
    this.isGenerating = false,
    this.isSaving = false,
    this.errorMessage,
    this.lessonPlan,
    this.savedId,
  });

  LessonPlanState copyWith({
    bool? isGenerating,
    bool? isSaving,
    String? errorMessage,
    LessonPlanModel? lessonPlan,
    String? savedId,
    bool clearError = false,
  }) {
    return LessonPlanState(
      isGenerating: isGenerating ?? this.isGenerating,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lessonPlan: lessonPlan ?? this.lessonPlan,
      savedId: savedId ?? this.savedId,
    );
  }
}

/// Notifier managing Lesson Plan generation, editing, and saving.
class LessonPlanNotifier extends StateNotifier<LessonPlanState> {
  final TeachingToolsRepository _repository;

  LessonPlanNotifier(this._repository) : super(const LessonPlanState());

  /// Generates a structured special-education lesson plan via the Edge Function.
  Future<void> generate({
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
    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      final plan = await _repository.generateLessonPlan(
        subject: subject,
        topic: topic,
        grade: grade,
        durationMinutes: durationMinutes,
        language: language,
        learnerNeeds: learnerNeeds,
        learningObjectives: learningObjectives,
        materialsAvailable: materialsAvailable,
        classSize: classSize,
      );
      state = state.copyWith(isGenerating: false, lessonPlan: plan);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Sets an existing plan (e.g. when editing or loading from library).
  void setPlan(LessonPlanModel plan) {
    state = state.copyWith(lessonPlan: plan, savedId: plan.id, clearError: true);
  }

  /// Updates current in-memory plan (during teacher inline edits).
  void updatePlan(LessonPlanModel updatedPlan) {
    state = state.copyWith(lessonPlan: updatedPlan);
  }

  /// Persists or updates the plan in the `ai_content` table.
  Future<String?> save({String? classId}) async {
    final current = state.lessonPlan;
    if (current == null) return null;

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      if (state.savedId != null) {
        // Update existing row
        await _repository.updateContent(
          id: state.savedId!,
          title: current.title,
          content: current.toContentJson(),
          classId: classId,
        );
        state = state.copyWith(isSaving: false);
        return state.savedId;
      } else {
        // Insert new row
        final newId = await _repository.saveContent(
          type: AppConstants.contentTypeLessonPlan,
          title: current.title,
          subject: current.subject,
          grade: current.grade,
          language: current.language,
          learnerNeeds: current.accommodations.map((a) => a.need).toList(),
          content: current.toContentJson(),
          classId: classId,
        );
        state = state.copyWith(
          isSaving: false,
          savedId: newId,
          lessonPlan: current.copyWith(id: newId, classId: classId),
        );
        return newId;
      }
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }
}

/// Provider for [LessonPlanNotifier].
final lessonPlanProvider =
    StateNotifierProvider<LessonPlanNotifier, LessonPlanState>((ref) {
  final repo = ref.watch(teachingToolsRepositoryProvider);
  return LessonPlanNotifier(repo);
});
