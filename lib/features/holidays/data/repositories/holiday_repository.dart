import 'package:intl/intl.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/holidays/domain/models/holiday_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing holidays in Supabase.
class HolidayRepository {
  final SupabaseClient _supabase;

  HolidayRepository(this._supabase);

  /// Fetches all holidays ordered by start date.
  Future<List<HolidayModel>> getHolidays() async {
    final response = await _supabase
        .from(AppConstants.tableHolidays)
        .select()
        .order('start_date', ascending: true);

    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map((item) => HolidayModel.fromMap(item)).toList();
  }

  /// Fetches only upcoming and active holidays (end_date >= today).
  Future<List<HolidayModel>> getUpcomingHolidays() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await _supabase
        .from(AppConstants.tableHolidays)
        .select()
        .gte('end_date', todayStr)
        .order('start_date', ascending: true);

    final list = (response as List).cast<Map<String, dynamic>>();
    return list.map((item) => HolidayModel.fromMap(item)).toList();
  }

  /// Inserts a new holiday (Admin only via RLS).
  Future<HolidayModel> createHoliday({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final response = await _supabase
        .from(AppConstants.tableHolidays)
        .insert({
          'name': name,
          'start_date': fmt.format(startDate),
          'end_date': fmt.format(endDate),
        })
        .select()
        .single();

    return HolidayModel.fromMap(response);
  }

  /// Updates an existing holiday (Admin only via RLS).
  Future<void> updateHoliday({
    required String id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    await _supabase
        .from(AppConstants.tableHolidays)
        .update({
          'name': name,
          'start_date': fmt.format(startDate),
          'end_date': fmt.format(endDate),
        })
        .eq('id', id);
  }

  /// Deletes a holiday (Admin only via RLS).
  Future<void> deleteHoliday(String id) async {
    await _supabase
        .from(AppConstants.tableHolidays)
        .delete()
        .eq('id', id);
  }
}
