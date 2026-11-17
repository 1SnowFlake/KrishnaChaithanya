import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/holidays/data/repositories/holiday_repository.dart';
import 'package:slkc_app/features/holidays/domain/models/holiday_model.dart';

/// Provides the [HolidayRepository] instance.
final holidayRepositoryProvider = Provider<HolidayRepository>((ref) {
  return HolidayRepository(SupabaseConfig.client);
});

/// Async notifier managing the list of holidays.
class HolidaysNotifier extends AsyncNotifier<List<HolidayModel>> {
  late final HolidayRepository _repo;

  @override
  FutureOr<List<HolidayModel>> build() {
    _repo = ref.watch(holidayRepositoryProvider);
    return _repo.getHolidays();
  }

  /// Refreshes holidays list from Supabase.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getHolidays());
  }

  /// Adds a new holiday (Admin).
  Future<void> createHoliday({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _repo.createHoliday(
      name: name,
      startDate: startDate,
      endDate: endDate,
    );
    await refresh();
  }

  /// Updates an existing holiday (Admin).
  Future<void> updateHoliday({
    required String id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _repo.updateHoliday(
      id: id,
      name: name,
      startDate: startDate,
      endDate: endDate,
    );
    await refresh();
  }

  /// Deletes a holiday (Admin).
  Future<void> deleteHoliday(String id) async {
    await _repo.deleteHoliday(id);
    await refresh();
  }
}

final holidaysNotifierProvider =
    AsyncNotifierProvider<HolidaysNotifier, List<HolidayModel>>(
  HolidaysNotifier.new,
);

/// Provider returning only upcoming or active holidays.
final upcomingHolidaysProvider = Provider<AsyncValue<List<HolidayModel>>>((ref) {
  final holidaysAsync = ref.watch(holidaysNotifierProvider);
  return holidaysAsync.whenData((holidays) {
    return holidays.where((h) => !h.isPast).toList();
  });
});

/// Provider returning today's holiday if today is an active holiday.
final todayHolidayProvider = Provider<HolidayModel?>((ref) {
  final holidays = ref.watch(holidaysNotifierProvider).value ?? [];
  final now = DateTime.now();
  for (final h in holidays) {
    if (h.containsDate(now)) {
      return h;
    }
  }
  return null;
});
