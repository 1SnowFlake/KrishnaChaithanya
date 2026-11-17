import 'package:intl/intl.dart';

/// Domain model representing a gazetted or custom school holiday.
class HolidayModel {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? createdAt;

  const HolidayModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.createdAt,
  });

  /// True if the holiday spans only a single calendar day.
  bool get isSingleDay =>
      startDate.year == endDate.year &&
      startDate.month == endDate.month &&
      startDate.day == endDate.day;

  /// Total number of days covered by this holiday.
  int get dayCount => endDate.difference(startDate).inDays + 1;

  /// Checks if a given date falls within this holiday range.
  bool containsDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  /// True if today is currently during this holiday.
  bool get isCurrent => containsDate(DateTime.now());

  /// True if this holiday will occur in the future.
  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    return s.isAfter(today);
  }

  /// True if this holiday has completely passed.
  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return e.isBefore(today);
  }

  /// Human-friendly display string for date range.
  String get formattedRange {
    final fmt = DateFormat('d MMM yyyy');
    if (isSingleDay) {
      return fmt.format(startDate);
    }
    return '${fmt.format(startDate)} – ${fmt.format(endDate)} ($dayCount days)';
  }

  factory HolidayModel.fromMap(Map<String, dynamic> map) {
    return HolidayModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled Holiday',
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final fmt = DateFormat('yyyy-MM-dd');
    return {
      'name': name,
      'start_date': fmt.format(startDate),
      'end_date': fmt.format(endDate),
    };
  }

  HolidayModel copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return HolidayModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
