import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/settings/data/repositories/settings_repository.dart';
import 'package:slkc_app/features/settings/domain/models/school_settings_model.dart';

/// Provides [SettingsRepository].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(SupabaseConfig.client);
});

/// AsyncNotifier managing school settings state.
class SettingsNotifier extends AsyncNotifier<SchoolSettingsModel> {
  late final SettingsRepository _repo;

  @override
  FutureOr<SchoolSettingsModel> build() {
    _repo = ref.watch(settingsRepositoryProvider);
    return _repo.getSettings();
  }

  /// Reloads settings from Supabase.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getSettings());
  }

  /// Toggles whether teachers are allowed to mark attendance on holidays / weekoffs.
  Future<void> toggleHolidayAttendance(bool allowed) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(allowHolidayAttendance: allowed);
    state = AsyncData(updated);
    await _repo.updateSettings(updated);
  }

  /// Toggles whether teachers can submit attendance after session cutoff.
  Future<void> togglePastCutoffAttendance(bool allowed) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(allowPastCutoff: allowed);
    state = AsyncData(updated);
    await _repo.updateSettings(updated);
  }

  /// Saves updated full settings.
  Future<void> saveSettings(SchoolSettingsModel settings) async {
    state = const AsyncLoading();
    await _repo.updateSettings(settings);
    state = AsyncData(settings);
  }
}

final settingsNotifierProvider =
    AsyncNotifierProvider<SettingsNotifier, SchoolSettingsModel>(
  SettingsNotifier.new,
);
