/// Domain model representing the school-wide settings row.
class SchoolSettingsModel {
  final String id;
  final String morningCutoff;     // e.g. '10:30:00'
  final String afternoonCutoff;   // e.g. '14:30:00'
  final List<int> weeklyOffDays;  // 0 = Sunday, 1 = Monday ... 6 = Saturday
  final double lowAttendanceThreshold;
  final String timezone;
  final bool allowHolidayAttendance;
  final bool allowPastCutoff;

  const SchoolSettingsModel({
    required this.id,
    this.morningCutoff = '10:30:00',
    this.afternoonCutoff = '14:30:00',
    this.weeklyOffDays = const [0],
    this.lowAttendanceThreshold = 75.0,
    this.timezone = 'Asia/Kolkata',
    this.allowHolidayAttendance = true,
    this.allowPastCutoff = true,
  });

  factory SchoolSettingsModel.fromMap(Map<String, dynamic> map) {
    List<int> offDays = [0];
    if (map['weekly_off_days'] is List) {
      offDays = (map['weekly_off_days'] as List).map((e) => (e as num).toInt()).toList();
    }

    return SchoolSettingsModel(
      id: map['id'] as String? ?? '',
      morningCutoff: map['morning_cutoff'] as String? ?? '10:30:00',
      afternoonCutoff: map['afternoon_cutoff'] as String? ?? '14:30:00',
      weeklyOffDays: offDays,
      lowAttendanceThreshold:
          (map['low_attendance_threshold'] as num?)?.toDouble() ?? 75.0,
      timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
      allowHolidayAttendance: map['allow_holiday_attendance'] as bool? ?? true,
      allowPastCutoff: map['allow_past_cutoff'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'morning_cutoff': morningCutoff,
      'afternoon_cutoff': afternoonCutoff,
      'weekly_off_days': weeklyOffDays,
      'low_attendance_threshold': lowAttendanceThreshold,
      'timezone': timezone,
      'allow_holiday_attendance': allowHolidayAttendance,
      'allow_past_cutoff': allowPastCutoff,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  SchoolSettingsModel copyWith({
    String? id,
    String? morningCutoff,
    String? afternoonCutoff,
    List<int>? weeklyOffDays,
    double? lowAttendanceThreshold,
    String? timezone,
    bool? allowHolidayAttendance,
    bool? allowPastCutoff,
  }) {
    return SchoolSettingsModel(
      id: id ?? this.id,
      morningCutoff: morningCutoff ?? this.morningCutoff,
      afternoonCutoff: afternoonCutoff ?? this.afternoonCutoff,
      weeklyOffDays: weeklyOffDays ?? this.weeklyOffDays,
      lowAttendanceThreshold:
          lowAttendanceThreshold ?? this.lowAttendanceThreshold,
      timezone: timezone ?? this.timezone,
      allowHolidayAttendance:
          allowHolidayAttendance ?? this.allowHolidayAttendance,
      allowPastCutoff: allowPastCutoff ?? this.allowPastCutoff,
    );
  }
}
