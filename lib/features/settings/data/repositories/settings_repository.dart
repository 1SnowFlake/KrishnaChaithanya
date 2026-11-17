import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/settings/domain/models/school_settings_model.dart';

/// Repository for reading and updating school settings in Supabase.
class SettingsRepository {
  final SupabaseClient _supabase;

  SettingsRepository(this._supabase);

  /// Reads the current school settings from Supabase.
  Future<SchoolSettingsModel> getSettings() async {
    final response = await _supabase
        .from(AppConstants.tableSettings)
        .select()
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return const SchoolSettingsModel(id: '');
    }

    return SchoolSettingsModel.fromMap(response);
  }

  /// Updates settings row in Supabase.
  Future<void> updateSettings(SchoolSettingsModel settings) async {
    final data = settings.toMap();
    if (settings.id.isNotEmpty) {
      await _supabase
          .from(AppConstants.tableSettings)
          .update(data)
          .eq('id', settings.id);
    } else {
      await _supabase.from(AppConstants.tableSettings).upsert(data);
    }
  }
}
