/// Timed instructional step within a lesson plan.
class LessonStepModel {
  final String stepName;
  final String title;
  final int durationMinutes;
  final String instructions;
  final String teacherActions;
  final String studentActions;

  const LessonStepModel({
    required this.stepName,
    required this.title,
    required this.durationMinutes,
    required this.instructions,
    required this.teacherActions,
    required this.studentActions,
  });

  factory LessonStepModel.fromMap(Map<String, dynamic> map) {
    return LessonStepModel(
      stepName: map['stepName'] as String? ?? 'step',
      title: map['title'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 10,
      instructions: map['instructions'] as String? ?? '',
      teacherActions: map['teacherActions'] as String? ?? '',
      studentActions: map['studentActions'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stepName': stepName,
      'title': title,
      'durationMinutes': durationMinutes,
      'instructions': instructions,
      'teacherActions': teacherActions,
      'studentActions': studentActions,
    };
  }

  LessonStepModel copyWith({
    String? stepName,
    String? title,
    int? durationMinutes,
    String? instructions,
    String? teacherActions,
    String? studentActions,
  }) {
    return LessonStepModel(
      stepName: stepName ?? this.stepName,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      instructions: instructions ?? this.instructions,
      teacherActions: teacherActions ?? this.teacherActions,
      studentActions: studentActions ?? this.studentActions,
    );
  }
}

/// Educational accommodation detail for special education learners.
class AccommodationModel {
  final String need;
  final String strategy;
  final List<String> materialsSuggested;

  const AccommodationModel({
    required this.need,
    required this.strategy,
    required this.materialsSuggested,
  });

  factory AccommodationModel.fromMap(Map<String, dynamic> map) {
    return AccommodationModel(
      need: map['need'] as String? ?? '',
      strategy: map['strategy'] as String? ?? '',
      materialsSuggested: (map['materialsSuggested'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'need': need,
      'strategy': strategy,
      'materialsSuggested': materialsSuggested,
    };
  }

  AccommodationModel copyWith({
    String? need,
    String? strategy,
    List<String>? materialsSuggested,
  }) {
    return AccommodationModel(
      need: need ?? this.need,
      strategy: strategy ?? this.strategy,
      materialsSuggested: materialsSuggested ?? this.materialsSuggested,
    );
  }
}

/// Domain model representing a full Special-Education Lesson Plan.
class LessonPlanModel {
  final String? id;                  // Set when saved to ai_content table
  final String title;
  final String subject;
  final String grade;
  final int durationMinutes;
  final String language;
  final List<String> objectives;
  final List<String> prerequisiteKnowledge;
  final List<String> materialsList;
  final List<LessonStepModel> steps;
  final List<AccommodationModel> accommodations;
  final List<String> questionsToAsk;
  final String homeworkOrExtension;
  final String assessmentIdeas;
  final String noteForParents;
  final String pedagogicalDisclaimer;
  final String? classId;
  final bool isShared;

  const LessonPlanModel({
    this.id,
    required this.title,
    required this.subject,
    required this.grade,
    required this.durationMinutes,
    this.language = 'English',
    required this.objectives,
    required this.prerequisiteKnowledge,
    required this.materialsList,
    required this.steps,
    required this.accommodations,
    required this.questionsToAsk,
    required this.homeworkOrExtension,
    required this.assessmentIdeas,
    required this.noteForParents,
    this.pedagogicalDisclaimer =
        'Educational suggestions only; not medical or diagnostic therapy.',
    this.classId,
    this.isShared = false,
  });

  factory LessonPlanModel.fromMap(Map<String, dynamic> map, {String? id, String? classId, bool isShared = false}) {
    return LessonPlanModel(
      id: id ?? map['id'] as String?,
      title: map['title'] as String? ?? 'Untitled Lesson Plan',
      subject: map['subject'] as String? ?? '',
      grade: map['grade'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 45,
      language: map['language'] as String? ?? 'English',
      objectives: (map['objectives'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      prerequisiteKnowledge: (map['prerequisiteKnowledge'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      materialsList: (map['materialsList'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      steps: (map['steps'] as List<dynamic>?)
              ?.map((e) => LessonStepModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      accommodations: (map['accommodations'] as List<dynamic>?)
              ?.map((e) => AccommodationModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      questionsToAsk: (map['questionsToAsk'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      homeworkOrExtension: map['homeworkOrExtension'] as String? ?? '',
      assessmentIdeas: map['assessmentIdeas'] as String? ?? '',
      noteForParents: map['noteForParents'] as String? ?? '',
      pedagogicalDisclaimer: map['pedagogicalDisclaimer'] as String? ??
          'Educational suggestions only; not medical or diagnostic therapy.',
      classId: classId ?? map['class_id'] as String?,
      isShared: isShared || (map['is_shared'] as bool? ?? false),
    );
  }

  Map<String, dynamic> toContentJson() {
    return {
      'title': title,
      'subject': subject,
      'grade': grade,
      'durationMinutes': durationMinutes,
      'language': language,
      'objectives': objectives,
      'prerequisiteKnowledge': prerequisiteKnowledge,
      'materialsList': materialsList,
      'steps': steps.map((s) => s.toMap()).toList(),
      'accommodations': accommodations.map((a) => a.toMap()).toList(),
      'questionsToAsk': questionsToAsk,
      'homeworkOrExtension': homeworkOrExtension,
      'assessmentIdeas': assessmentIdeas,
      'noteForParents': noteForParents,
      'pedagogicalDisclaimer': pedagogicalDisclaimer,
    };
  }

  LessonPlanModel copyWith({
    String? id,
    String? title,
    String? subject,
    String? grade,
    int? durationMinutes,
    String? language,
    List<String>? objectives,
    List<String>? prerequisiteKnowledge,
    List<String>? materialsList,
    List<LessonStepModel>? steps,
    List<AccommodationModel>? accommodations,
    List<String>? questionsToAsk,
    String? homeworkOrExtension,
    String? assessmentIdeas,
    String? noteForParents,
    String? pedagogicalDisclaimer,
    String? classId,
    bool? isShared,
  }) {
    return LessonPlanModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      language: language ?? this.language,
      objectives: objectives ?? this.objectives,
      prerequisiteKnowledge: prerequisiteKnowledge ?? this.prerequisiteKnowledge,
      materialsList: materialsList ?? this.materialsList,
      steps: steps ?? this.steps,
      accommodations: accommodations ?? this.accommodations,
      questionsToAsk: questionsToAsk ?? this.questionsToAsk,
      homeworkOrExtension: homeworkOrExtension ?? this.homeworkOrExtension,
      assessmentIdeas: assessmentIdeas ?? this.assessmentIdeas,
      noteForParents: noteForParents ?? this.noteForParents,
      pedagogicalDisclaimer: pedagogicalDisclaimer ?? this.pedagogicalDisclaimer,
      classId: classId ?? this.classId,
      isShared: isShared ?? this.isShared,
    );
  }
}
