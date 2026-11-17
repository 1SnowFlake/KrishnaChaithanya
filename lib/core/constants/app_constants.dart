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
  static const String fnCreateTeacher = 'create-teacher';

  // ── Route paths ───────────────────────────────────────
  static const String pathLogin             = '/login';
  static const String pathAdminHome         = '/admin';
  static const String pathAdminReports      = '/admin/reports';
  static const String pathTeacherHome       = '/teacher';
  static const String pathTeacherAttendance = '/teacher/attendance';
  static const String pathDeactivated       = '/deactivated';
  static const String pathSplash            = '/';
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

