import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/theme/theme_toggle_button.dart';
import 'package:slkc_app/features/attendance/presentation/screens/admin_attendance_screen.dart';
import 'package:slkc_app/features/attendance/presentation/screens/audit_log_screen.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:slkc_app/features/classes/presentation/screens/classes_tab.dart';
import 'package:slkc_app/features/holidays/presentation/screens/holiday_list_screen.dart';
import 'package:slkc_app/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:slkc_app/features/reports/presentation/screens/reports_screen.dart';
import 'package:slkc_app/features/settings/presentation/screens/settings_sheet.dart';
import 'package:slkc_app/features/students/presentation/screens/students_tab.dart';
import 'package:slkc_app/features/substitutes/presentation/screens/substitute_management_screen.dart';
import 'package:slkc_app/features/teachers/presentation/screens/teachers_tab.dart';

/// Admin Dashboard featuring tabbed navigation across:
/// 1. Teachers management (CRUD via Edge Function)
/// 2. Classes management (CRUD and primary teacher assignment)
/// 3. Students management (CRUD and CSV bulk import)
/// 4. Attendance review & override for ANY class/date/session
/// 5. Audit Log viewer with full mutation history
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    TeachersTab(),
    ClassesTab(),
    StudentsTab(),
    AdminAttendanceScreen(),
    AuditLogScreen(),
  ];

  final List<String> _titles = const [
    'Staff Directory',
    'Classes & Sections',
    'Students Directory',
    'Attendance Management',
    'Attendance Audit Trail',
  ];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authNotifierProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_currentIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Admin: ${profile?.name ?? 'Admin'}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          const NotificationBellButton(),
          IconButton(
            tooltip: 'Reports & Analytics',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Holiday Calendar',
            icon: const Icon(Icons.event_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HolidayListScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Substitute Assignments',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubstituteManagementScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Attendance Settings & Rules',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SettingsSheet(),
              );
            },
          ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Staff',
          ),
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            selectedIcon: Icon(Icons.class_),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Audit Log',
          ),
        ],
      ),
    );
  }
}
