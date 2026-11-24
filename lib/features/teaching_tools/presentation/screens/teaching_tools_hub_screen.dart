import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/widgets/app_card.dart';

/// Hub screen providing quick access to all AI Teaching Tools:
/// 1. Special-Education Lesson Plan Generator
/// 2. Accessible Worksheet Generator
/// 3. Classroom Quiz Generator
/// 4. My Teaching Library & Class Materials
class TeachingToolsHubScreen extends StatelessWidget {
  const TeachingToolsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Teaching Tools',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Informative banner on educational safety & privacy
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Privacy & Safety Guarantee',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No student names or personal data are ever sent to AI. Accommodations are educational suggestions to support classroom teaching.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Tool 1: Lesson Plan Generator ────────────────────────
          _buildToolCard(
            context: context,
            title: 'Lesson Plan Generator',
            description:
                'Create timed instructional plans with built-in accommodations for autism, ADHD, sensory needs, and mixed-ability classrooms.',
            icon: Icons.menu_book_rounded,
            accentColor: const Color(0xFF1565C0), // Blue 800
            route: AppConstants.pathLessonPlanGenerator,
            badgeText: 'Timed & Accommodated',
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Tool 2: Worksheet Generator ──────────────────────────
          _buildToolCard(
            context: context,
            title: 'Accessible Worksheet Generator',
            description:
                'Generate printable A4 worksheets with large print, fill-in-the-blanks, matching pairs, and separate teacher answer keys.',
            icon: Icons.assignment_outlined,
            accentColor: const Color(0xFF2E7D32), // Green 800
            route: AppConstants.pathWorksheetGenerator,
            badgeText: 'Printable A4 + Answer Key',
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Tool 3: Classroom Quiz Generator ─────────────────────
          _buildToolCard(
            context: context,
            title: 'Classroom Quiz Generator',
            description:
                'Generate positive review quizzes with gentle explanations. Includes in-app classroom play mode with text-to-speech read-aloud.',
            icon: Icons.quiz_outlined,
            accentColor: const Color(0xFF6A1B9A), // Purple 800
            route: AppConstants.pathQuizGenerator,
            badgeText: 'Print or Play In-App',
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Tool 4: Shared Library ───────────────────────────────
          _buildToolCard(
            context: context,
            title: 'My Teaching Library',
            description:
                'Browse your saved lesson plans, worksheets, and quizzes. Attach materials to your classes or export them to PDF.',
            icon: Icons.folder_special_outlined,
            accentColor: const Color(0xFFE65100), // Orange 900
            route: AppConstants.pathAiLibrary,
            badgeText: 'Saved Materials',
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String route,
    required String badgeText,
  }) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () => context.push(route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
