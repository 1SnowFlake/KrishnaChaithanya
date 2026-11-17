/// Tracks whether morning and afternoon attendance sessions
/// have already been submitted today for a specific class.
class ClassSessionStatus {
  final String classId;
  final bool isHoliday;
  final String? holidayName;
  final bool isWeeklyOff;
  final bool morningSubmitted;
  final int morningPresent;
  final int morningAbsent;
  final bool afternoonSubmitted;
  final int afternoonPresent;
  final int afternoonAbsent;
  final bool morningCutoffPassed;
  final bool afternoonCutoffPassed;

  const ClassSessionStatus({
    required this.classId,
    this.isHoliday = false,
    this.holidayName,
    this.isWeeklyOff = false,
    this.morningSubmitted = false,
    this.morningPresent = 0,
    this.morningAbsent = 0,
    this.afternoonSubmitted = false,
    this.afternoonPresent = 0,
    this.afternoonAbsent = 0,
    this.morningCutoffPassed = false,
    this.afternoonCutoffPassed = false,
  });

  bool get isNonWorkingDay => isHoliday || isWeeklyOff;

  String get closureReason {
    if (isHoliday) return 'Holiday: ${holidayName ?? 'School Closed'}';
    if (isWeeklyOff) return 'Weekly Off: School is closed today.';
    return '';
  }
}
