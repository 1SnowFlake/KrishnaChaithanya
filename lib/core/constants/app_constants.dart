/// App-wide constants.
/// Centralises magic strings so they're easy to find and change.
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ── Supabase table names ──────────────────────────────
  static const String tableProfiles      = 'profiles';
  static const String tableClasses       = 'classes';
  static const String tableStudents      = 'students';
  static const String tableAttendance    = 'attendance';
  static const String tableAttendanceLog = 'attendance_log';
  static const String tableHolidays      = 'holidays';
  static const String tableSettings      = 'settings';
  static const String tableSubstitutes   = 'substitute_assignments';
  static const String tableNotifications = 'notifications';
  static const String tableTeacherAttendance = 'teacher_attendance';

  // ── AI Learning Assistant tables ──────────────────────
  static const String tableAiContent        = 'ai_content';
  static const String tableVideoSearchCache = 'video_search_cache';
  static const String tableSavedVideos      = 'saved_videos';
  static const String tableVideoFeedback    = 'video_feedback';
  static const String tableGeneratedVideos  = 'generated_videos';
  static const String tableAiUsageLog       = 'ai_usage_log';
  static const String tableAiRateLimits     = 'ai_rate_limits';

  // ── AI Content Types ──────────────────────────────────
  static const String contentTypeLessonPlan = 'lesson_plan';
  static const String contentTypeWorksheet  = 'worksheet';
  static const String contentTypeQuiz       = 'quiz';

  // ── Storage buckets ───────────────────────────────────
  static const String bucketLearningMedia   = 'learning_media';

  // ── Session values (must match DB CHECK constraints) ──
  static const String sessionMorning   = 'morning';
  static const String sessionAfternoon = 'afternoon';

  // ── Status values (must match DB CHECK constraints) ───
  static const String statusPresent = 'present';
  static const String statusAbsent  = 'absent';

  // ── Roles ─────────────────────────────────────────────
  static const String roleAdmin   = 'admin';
  static const String roleTeacher = 'teacher';

  // ── Edge Function names ───────────────────────────────
  static const String fnCreateTeacher            = 'create-teacher';
  static const String fnMissingAttendanceCheck   = 'missing-attendance-check';
  static const String fnSuggestVideos            = 'suggest-videos';
  static const String fnGenerateLessonVideo      = 'generate-lesson-video';
  static const String fnGenerateContent          = 'generate-content';

  // ── Route paths ───────────────────────────────────────
  static const String pathLogin                  = '/login';
  static const String pathAdminHome              = '/admin';
  static const String pathAdminReports           = '/admin/reports';
  static const String pathAdminAiUsage           = '/admin/ai-usage';
  static const String pathTeacherHome            = '/teacher';
  static const String pathTeacherAttendance      = '/teacher/attendance';
  static const String pathLearningAssistant      = '/learning-assistant';
  static const String pathGeneratedVideoEditor   = '/learning-assistant/editor';
  static const String pathTeachingTools          = '/teaching-tools';
  static const String pathLessonPlanGenerator    = '/teaching-tools/lesson-plan';
  static const String pathWorksheetGenerator     = '/teaching-tools/worksheet';
  static const String pathQuizGenerator          = '/teaching-tools/quiz';
  static const String pathAiLibrary              = '/teaching-tools/library';
  static const String pathDeactivated            = '/deactivated';
  static const String pathSplash                 = '/';
}

/// Expanded Staff Roles recognized across the school.
class StaffRoles {
  StaffRoles._();

  static const String teacher = 'Teacher';
  static const String assistantTeacher = 'Assistant Teacher';
  static const String warden = 'Warden';
  static const String cook = 'Cook';
  static const String aya = 'Aya';
  static const String watchman = 'Watchman';
  static const String psychologist = 'Psychologist';
  static const String danceMaster = 'Dance Master';
  static const String doctor = 'Doctor';
  static const String psychotherapist = 'Psychotherapist';
  static const String admin = 'Admin';
  static const String other = 'Other (Custom)';

  static const List<String> presetRoles = [
    teacher,
    assistantTeacher,
    warden,
    cook,
    aya,
    watchman,
    psychologist,
    danceMaster,
    doctor,
    psychotherapist,
    admin,
  ];
}

/// Recognized special-education learner needs.
class LearnerNeeds {
  LearnerNeeds._();

  static const String autismSpectrum          = 'autism_spectrum';
  static const String adhd                    = 'adhd';
  static const String intellectualDisability  = 'intellectual_disability';
  static const String hearingImpairment       = 'hearing_impairment';
  static const String visualImpairment        = 'visual_impairment';
  static const String dyslexia                = 'dyslexia';
  static const String speechLanguageDelay     = 'speech_language_delay';
  static const String motorPhysicalDisability = 'motor_physical_disability';
  static const String multipleDisabilities    = 'multiple_disabilities';
  static const String mixedAbility            = 'mixed_ability';
  static const String none                    = 'none';

  /// Human-readable labels for the UI
  static const Map<String, String> labels = {
    autismSpectrum: 'Autism Spectrum',
    adhd: 'ADHD',
    intellectualDisability: 'Intellectual Disability',
    hearingImpairment: 'Hearing Impairment / Deaf',
    visualImpairment: 'Visual Impairment / Low Vision',
    dyslexia: 'Dyslexia & Reading Difficulty',
    speechLanguageDelay: 'Speech & Language Delay',
    motorPhysicalDisability: 'Motor / Physical Disability',
    multipleDisabilities: 'Multiple Disabilities',
    mixedAbility: 'Mixed-Ability Classroom',
    none: 'Standard / No Accommodations Needed',
  };

  static const List<String> all = [
    autismSpectrum,
    adhd,
    intellectualDisability,
    hearingImpairment,
    visualImpairment,
    dyslexia,
    speechLanguageDelay,
    motorPhysicalDisability,
    multipleDisabilities,
    mixedAbility,
    none,
  ];
}

