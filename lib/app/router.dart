import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/attendance/presentation/screens/take_attendance_screen.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:slkc_app/features/auth/presentation/screens/deactivated_screen.dart';
import 'package:slkc_app/features/auth/presentation/screens/login_screen.dart';
import 'package:slkc_app/features/dashboard/presentation/screens/admin_home_screen.dart';
import 'package:slkc_app/features/dashboard/presentation/screens/teacher_home_screen.dart';
import 'package:slkc_app/features/reports/presentation/screens/reports_screen.dart';
import 'package:slkc_app/features/teaching_tools/domain/models/lesson_plan_model.dart';
import 'package:slkc_app/features/teaching_tools/presentation/screens/lesson_plan_form_screen.dart';
import 'package:slkc_app/features/teaching_tools/presentation/screens/lesson_plan_result_screen.dart';
import 'package:slkc_app/features/teaching_tools/presentation/screens/teaching_tools_hub_screen.dart';

/// Splash screen shown briefly while checking initial session & profile.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Provides the configured [GoRouter] with role-based routing guards.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(authRouterListenableProvider);

  return GoRouter(
    initialLocation: AppConstants.pathSplash,
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: AppConstants.pathSplash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.pathLogin,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConstants.pathDeactivated,
        builder: (context, state) => const DeactivatedScreen(),
      ),
      GoRoute(
        path: AppConstants.pathAdminHome,
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: AppConstants.pathAdminReports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppConstants.pathTeacherHome,
        builder: (context, state) => const TeacherHomeScreen(),
      ),
      GoRoute(
        path: AppConstants.pathTeacherAttendance,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return TakeAttendanceScreen(
            classId: extra['classId'] as String? ?? '',
            className: extra['className'] as String? ?? '',
            session: extra['session'] as String? ?? AppConstants.sessionMorning,
            isEdit: extra['isEdit'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: AppConstants.pathTeachingTools,
        builder: (context, state) => const TeachingToolsHubScreen(),
      ),
      GoRoute(
        path: AppConstants.pathLessonPlanGenerator,
        builder: (context, state) => const LessonPlanFormScreen(),
      ),
      GoRoute(
        path: '${AppConstants.pathLessonPlanGenerator}/result',
        builder: (context, state) {
          final plan = state.extra as LessonPlanModel;
          return LessonPlanResultScreen(plan: plan);
        },
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;

      // 1. If still loading initial profile, keep on splash screen
      if (authState.isLoading) {
        return location == AppConstants.pathSplash ? null : AppConstants.pathSplash;
      }

      final profile = authState.value;

      // 2. If user is NOT logged in
      if (profile == null) {
        // If already going to /login, let them pass
        if (location == AppConstants.pathLogin) {
          return null;
        }
        // Otherwise, send to /login
        return AppConstants.pathLogin;
      }

      // 3. If user is authenticated but DEACTIVATED
      if (!profile.isActive) {
        if (location == AppConstants.pathDeactivated) {
          return null;
        }
        return AppConstants.pathDeactivated;
      }

      // 4. If active user is on splash, login, or deactivated screen, route to their role dashboard
      final isEntryScreen = location == AppConstants.pathSplash ||
          location == AppConstants.pathLogin ||
          location == AppConstants.pathDeactivated;

      if (isEntryScreen) {
        return profile.isAdmin
            ? AppConstants.pathAdminHome
            : AppConstants.pathTeacherHome;
      }

      // 5. Role-based guards for protected sections
      // Teachers cannot access /admin
      if (location.startsWith(AppConstants.pathAdminHome) && !profile.isAdmin) {
        return AppConstants.pathTeacherHome;
      }

      // Admins cannot access /teacher (keeps roles strictly isolated)
      if (location.startsWith(AppConstants.pathTeacherHome) && !profile.isTeacher) {
        return AppConstants.pathAdminHome;
      }

      // No redirect needed; permit navigation
      return null;
    },
  );
});
