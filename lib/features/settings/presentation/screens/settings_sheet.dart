import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/theme/theme_mode_selector.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/auth/presentation/widgets/change_password_dialog.dart';
import 'package:slkc_app/features/holidays/presentation/screens/holiday_list_screen.dart';
import 'package:slkc_app/features/settings/domain/models/school_settings_model.dart';
import 'package:slkc_app/features/settings/presentation/providers/settings_provider.dart';

/// Modal bottom sheet allowing Admins to configure school attendance rules,
/// weekly offs, cutoff times, and holiday/weekend bypass permissions for teachers.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  late bool _allowHoliday;
  late bool _allowPastCutoff;
  late TextEditingController _morningCutoffCtrl;
  late TextEditingController _afternoonCutoffCtrl;
  late double _threshold;
  late List<int> _weeklyOffDays;
  bool _isInitialized = false;
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _daysOfWeek = [
    {'day': 0, 'label': 'Sun'},
    {'day': 1, 'label': 'Mon'},
    {'day': 2, 'label': 'Tue'},
    {'day': 3, 'label': 'Wed'},
    {'day': 4, 'label': 'Thu'},
    {'day': 5, 'label': 'Fri'},
    {'day': 6, 'label': 'Sat'},
  ];

  void _initFields(SchoolSettingsModel settings) {
    if (!_isInitialized) {
      _allowHoliday = settings.allowHolidayAttendance;
      _allowPastCutoff = settings.allowPastCutoff;
      _morningCutoffCtrl = TextEditingController(text: settings.morningCutoff);
      _afternoonCutoffCtrl = TextEditingController(text: settings.afternoonCutoff);
      _threshold = settings.lowAttendanceThreshold;
      _weeklyOffDays = List<int>.from(settings.weeklyOffDays);
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _morningCutoffCtrl.dispose();
      _afternoonCutoffCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 10 : 10;
    final initialMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hourStr:$minuteStr:00';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final theme = Theme.of(context);

    return settingsAsync.when(
      loading: () => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 250,
        child: Center(
          child: Text(
            AppErrorHandler.getErrorMessage(e),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
      data: (settings) {
        _initFields(settings);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Holiday Calendar Shortcut
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'School Attendance Rules',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: const Text('Holidays', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HolidayListScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Configure cutoff policies, weekly offs, and permission rules.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── 1. Weekly Off Days Selector ──────────────────────────────
                const Text(
                  'Weekly Off Days',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _daysOfWeek.map((d) {
                    final int dayNum = d['day'] as int;
                    final String label = d['label'] as String;
                    final isSelected = _weeklyOffDays.contains(dayNum);

                    return FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: theme.colorScheme.primary,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_weeklyOffDays.contains(dayNum)) {
                              _weeklyOffDays.add(dayNum);
                              _weeklyOffDays.sort();
                            }
                          } else {
                            _weeklyOffDays.remove(dayNum);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── 2. Teacher Holiday/Weekend Permission Toggle ─────────────
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: CircleAvatar(
                    backgroundColor: _allowHoliday
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.beach_access_rounded,
                      color: _allowHoliday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: const Text(
                    'Allow Attendance on Holidays / Weekly Offs',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    _allowHoliday
                        ? 'Enabled: Teachers can take attendance on weekends or any holiday.'
                        : 'Blocked: Teachers cannot submit attendance on weekly offs or holidays.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _allowHoliday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _allowHoliday,
                  onChanged: (val) => setState(() => _allowHoliday = val),
                ),
                const SizedBox(height: 8),

                // ── 3. Cutoff Bypass Toggle ──────────────────────────────────
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: CircleAvatar(
                    backgroundColor: _allowPastCutoff
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.timer_outlined,
                      color: _allowPastCutoff
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: const Text(
                    'Allow Attendance Past Cutoff Times',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    _allowPastCutoff
                        ? 'Enabled: Teachers can submit or edit attendance anytime during the day.'
                        : 'Strict: Submissions locked after cutoff times (Admin only).',
                    style: TextStyle(
                      fontSize: 12,
                      color: _allowPastCutoff
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _allowPastCutoff,
                  onChanged: (val) => setState(() => _allowPastCutoff = val),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // ── 4. Cutoff Times with Native TimePickers ──────────────────
                const Text(
                  'Session Cutoff Times',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _morningCutoffCtrl,
                        readOnly: true,
                        onTap: () => _pickTime(_morningCutoffCtrl),
                        decoration: InputDecoration(
                          labelText: 'Morning Cutoff',
                          hintText: '10:30:00',
                          prefixIcon: const Icon(Icons.wb_sunny_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time, size: 18),
                            onPressed: () => _pickTime(_morningCutoffCtrl),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _afternoonCutoffCtrl,
                        readOnly: true,
                        onTap: () => _pickTime(_afternoonCutoffCtrl),
                        decoration: InputDecoration(
                          labelText: 'Afternoon Cutoff',
                          hintText: '14:30:00',
                          prefixIcon: const Icon(Icons.wb_twilight_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time, size: 18),
                            onPressed: () => _pickTime(_afternoonCutoffCtrl),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 5. Low Attendance Warning Threshold ─────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Low Attendance Alert Threshold',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '${_threshold.toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _threshold,
                  min: 50.0,
                  max: 95.0,
                  divisions: 9,
                  label: '${_threshold.toInt()}%',
                  onChanged: (val) => setState(() => _threshold = val),
                ),
                const SizedBox(height: 16),

                // ── 6. Theme & Appearance ───────────────────────────────────
                const Divider(),
                const SizedBox(height: 12),
                const ThemeModeSelector(),
                const SizedBox(height: 16),

                // ── 7. Account Security ────────────────────────────────────
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Change Password',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text('Update your login password'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    ChangePasswordDialog.show(context);
                  },
                ),
                const SizedBox(height: 20),

                // ── Save Button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSaving ? null : () => _save(settings),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(SchoolSettingsModel currentSettings) async {
    setState(() => _isSaving = true);
    try {
      final updated = currentSettings.copyWith(
        allowHolidayAttendance: _allowHoliday,
        allowPastCutoff: _allowPastCutoff,
        morningCutoff: _morningCutoffCtrl.text.trim(),
        afternoonCutoff: _afternoonCutoffCtrl.text.trim(),
        lowAttendanceThreshold: _threshold,
        weeklyOffDays: _weeklyOffDays,
      );

      await ref.read(settingsNotifierProvider.notifier).saveSettings(updated);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.getErrorMessage(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
