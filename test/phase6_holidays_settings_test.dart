import 'package:flutter_test/flutter_test.dart';
import 'package:slkc_app/features/holidays/data/repositories/holiday_repository.dart';
import 'package:slkc_app/features/settings/data/repositories/settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const supabaseUrl = 'https://cnwcambhldsmvpuwgcqj.supabase.co';
  const supabaseAnonKey = 'sb_publishable_IlAsVPCWoKdFl-Xc5RxaYA_SvftODPl';

  test('Phase 6 E2E: Holiday Calendar CRUD & School Settings Verification', () async {
    print('\n==========================================');
    print('STEP 1: Initializing Supabase client...');
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

    print('\n==========================================');
    print('STEP 2: Signing in as admin@school.com...');
    final authRes = await client.auth.signInWithPassword(
      email: 'admin@school.com',
      password: 'Test@123',
    );
    expect(authRes.user, isNotNull);
    print('Logged in successfully as Admin: ${authRes.user!.id}');

    final holidayRepo = HolidayRepository(client);
    final settingsRepo = SettingsRepository(client);

    // ── 3. Test Holiday Retrieval ──────────────────────────────────────
    print('\n==========================================');
    print('STEP 3: Fetching existing holidays...');
    final initialHolidays = await holidayRepo.getHolidays();
    print('Existing holidays count: ${initialHolidays.length}');
    for (final h in initialHolidays) {
      print(' - ${h.name} (${h.formattedRange})');
    }

    // ── 4. Test Holiday Creation ───────────────────────────────────────
    print('\n==========================================');
    print('STEP 4: Admin creating a new holiday...');
    final testStart = DateTime.now().add(const Duration(days: 30));
    final testEnd = DateTime.now().add(const Duration(days: 32));
    const testHolidayName = 'Annual Sports Festival 2026';

    final createdHoliday = await holidayRepo.createHoliday(
      name: testHolidayName,
      startDate: testStart,
      endDate: testEnd,
    );
    expect(createdHoliday.id, isNotEmpty);
    expect(createdHoliday.name, equals(testHolidayName));
    expect(createdHoliday.dayCount, equals(3));
    print('Holiday created successfully: ${createdHoliday.name} (ID: ${createdHoliday.id})');

    // ── 5. Test Holiday Update ─────────────────────────────────────────
    print('\n==========================================');
    print('STEP 5: Admin updating holiday details...');
    const updatedName = 'Annual Sports Festival (Rescheduled)';
    final updatedEnd = testEnd.add(const Duration(days: 1));

    await holidayRepo.updateHoliday(
      id: createdHoliday.id,
      name: updatedName,
      startDate: testStart,
      endDate: updatedEnd,
    );

    final refreshedList = await holidayRepo.getHolidays();
    final updatedHoliday = refreshedList.firstWhere((h) => h.id == createdHoliday.id);
    expect(updatedHoliday.name, equals(updatedName));
    expect(updatedHoliday.dayCount, equals(4));
    print('Holiday updated successfully: ${updatedHoliday.name} (${updatedHoliday.formattedRange})');

    // ── 6. Test Settings Retrieval & Update ────────────────────────────
    print('\n==========================================');
    print('STEP 6: Reading and modifying school settings...');
    final initialSettings = await settingsRepo.getSettings();
    print('Current Settings: Cutoffs: ${initialSettings.morningCutoff} / ${initialSettings.afternoonCutoff}, Weekly Offs: ${initialSettings.weeklyOffDays}, Allow Holiday: ${initialSettings.allowHolidayAttendance}');

    final newSettings = initialSettings.copyWith(
      morningCutoff: '11:00:00',
      afternoonCutoff: '15:00:00',
      weeklyOffDays: [0, 6], // Sun & Sat
      allowHolidayAttendance: true,
      allowPastCutoff: true,
    );
    await settingsRepo.updateSettings(newSettings);

    final verifiedSettings = await settingsRepo.getSettings();
    expect(verifiedSettings.morningCutoff, equals('11:00:00'));
    expect(verifiedSettings.afternoonCutoff, equals('15:00:00'));
    expect(verifiedSettings.weeklyOffDays, containsAll([0, 6]));
    print('Settings successfully verified: Weekly Offs: ${verifiedSettings.weeklyOffDays}, Cutoffs: ${verifiedSettings.morningCutoff} / ${verifiedSettings.afternoonCutoff}');

    // ── 7. Test Holiday Deletion ───────────────────────────────────────
    print('\n==========================================');
    print('STEP 7: Admin deleting the test holiday...');
    await holidayRepo.deleteHoliday(createdHoliday.id);

    final afterDeleteList = await holidayRepo.getHolidays();
    expect(afterDeleteList.any((h) => h.id == createdHoliday.id), isFalse);
    print('Holiday deleted and confirmed absent from holidays table!');

    print('\n==========================================');
    print('SUCCESS: Phase 6 Holiday Calendar & School Settings fully verified!');
  });
}
