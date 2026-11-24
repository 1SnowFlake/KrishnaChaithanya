import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/widgets/app_card.dart';
import 'package:slkc_app/core/widgets/primary_button.dart';
import 'package:slkc_app/core/widgets/section_header.dart';
import 'package:slkc_app/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:slkc_app/features/teaching_tools/domain/models/lesson_plan_model.dart';
import 'package:slkc_app/features/teaching_tools/presentation/providers/teaching_tools_provider.dart';

/// Screen displaying the generated Lesson Plan with full special-education details,
/// inline editing, class attachment, and saving to the library.
class LessonPlanResultScreen extends ConsumerStatefulWidget {
  final LessonPlanModel plan;

  const LessonPlanResultScreen({super.key, required this.plan});

  @override
  ConsumerState<LessonPlanResultScreen> createState() => _LessonPlanResultScreenState();
}

class _LessonPlanResultScreenState extends ConsumerState<LessonPlanResultScreen> {
  late LessonPlanModel _currentPlan;
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.plan;
    _selectedClassId = widget.plan.classId;
  }

  void _openEditDialog() {
    final titleCtrl = TextEditingController(text: _currentPlan.title);
    final homeworkCtrl = TextEditingController(text: _currentPlan.homeworkOrExtension);
    final parentNoteCtrl = TextEditingController(text: _currentPlan.noteForParents);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Lesson Plan Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Lesson Title'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: homeworkCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Homework / Extension Activity'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: parentNoteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note for Parents'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentPlan = _currentPlan.copyWith(
                  title: titleCtrl.text.trim(),
                  homeworkOrExtension: homeworkCtrl.text.trim(),
                  noteForParents: parentNoteCtrl.text.trim(),
                );
              });
              ref.read(lessonPlanProvider.notifier).updatePlan(_currentPlan);
              Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePlan() async {
    final notifier = ref.read(lessonPlanProvider.notifier);
    notifier.updatePlan(_currentPlan);
    final savedId = await notifier.save(classId: _selectedClassId);

    if (!mounted) return;
    if (savedId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson plan saved to your library!'),
          backgroundColor: AppColors.present,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(lessonPlanProvider);
    final isSaving = state.isSaving;
    final isSaved = state.savedId != null;
    final classesAsync = ref.watch(teacherClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Plan'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Plan Details',
            onPressed: _openEditDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Mandatory AI Notice Banner ───────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'AI-generated lesson plan. Please preview and adjust before using in class.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Header Card ──────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentPlan.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildPill(Icons.school, _currentPlan.subject, theme.colorScheme.primary),
                    _buildPill(Icons.auto_stories, _currentPlan.grade, const Color(0xFF2E7D32)),
                    _buildPill(Icons.schedule, '${_currentPlan.durationMinutes} mins', const Color(0xFFE65100)),
                    _buildPill(Icons.translate, _currentPlan.language, const Color(0xFF6A1B9A)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Objectives ───────────────────────────────────────────
          const SectionHeader(title: 'Learning Objectives'),
          ..._currentPlan.objectives.map(
            (obj) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18, color: AppColors.present),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      obj,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Materials Checklist ──────────────────────────────────
          if (_currentPlan.materialsList.isNotEmpty) ...[
            const SectionHeader(title: 'Classroom Materials & Sensory Props'),
            AppCard(
              child: Column(
                children: _currentPlan.materialsList
                    .map(
                      (mat) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(mat, style: theme.textTheme.bodyMedium)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Timed Steps Timeline ─────────────────────────────────
          const SectionHeader(title: 'Timed Instructional Flow'),
          ..._currentPlan.steps.map((step) => _buildStepCard(step, theme)),
          const SizedBox(height: AppSpacing.lg),

          // ── Differentiated Accommodations ────────────────────────
          if (_currentPlan.accommodations.isNotEmpty) ...[
            const SectionHeader(title: 'Differentiated Accommodations'),
            ..._currentPlan.accommodations.map((acc) => _buildAccommodationCard(acc, theme)),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Questions to Ask ─────────────────────────────────────
          if (_currentPlan.questionsToAsk.isNotEmpty) ...[
            const SectionHeader(title: 'Check for Understanding Questions'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _currentPlan.questionsToAsk
                    .asMap()
                    .entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Parent Note & Homework ───────────────────────────────
          const SectionHeader(title: 'Family & Practice Connection'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentPlan.homeworkOrExtension.isNotEmpty) ...[
                  Text(
                    'Practice / Extension Activity:',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(_currentPlan.homeworkOrExtension, style: theme.textTheme.bodySmall),
                  const Divider(height: 20),
                ],
                Text(
                  'Note for Parents:',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(_currentPlan.noteForParents, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Pedagogical Disclaimer ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              _currentPlan.pedagogicalDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Class Attachment (Optional) ──────────────────────────
          classesAsync.when(
            data: (classList) {
              if (classList.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedClassId,
                  decoration: const InputDecoration(
                    labelText: 'Attach to Class (Optional)',
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No class assigned (Personal Library)')),
                    ...classList.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedClassId = val),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),

          // ── Save Button ──────────────────────────────────────────
          PrimaryButton(
            label: isSaved ? 'Saved to Library ✓' : 'Save to My Library',
            icon: isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_outlined,
            isLoading: isSaving,
            onPressed: isSaving ? null : _savePlan,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildStepCard(LessonStepModel step, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${step.durationMinutes} min',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(step.instructions, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher: ${step.teacherActions}',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Students: ${step.studentActions}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccommodationCard(AccommodationModel acc, ThemeData theme) {
    final friendlyName = LearnerNeeds.labels[acc.need] ?? acc.need;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.accessibility_new_rounded, size: 18, color: AppColors.substitute),
                const SizedBox(width: 8),
                Text(
                  friendlyName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.substitute,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(acc.strategy, style: theme.textTheme.bodySmall),
            if (acc.materialsSuggested.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Props: ${acc.materialsSuggested.join(", ")}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
