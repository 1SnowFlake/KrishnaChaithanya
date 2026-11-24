import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import 'package:slkc_app/core/widgets/primary_button.dart';
import 'package:slkc_app/features/teaching_tools/presentation/providers/teaching_tools_provider.dart';
import 'package:slkc_app/features/teaching_tools/presentation/screens/lesson_plan_result_screen.dart';

/// Form screen for configuring and generating an accessible Lesson Plan.
class LessonPlanFormScreen extends ConsumerStatefulWidget {
  const LessonPlanFormScreen({super.key});

  @override
  ConsumerState<LessonPlanFormScreen> createState() => _LessonPlanFormScreenState();
}

class _LessonPlanFormScreenState extends ConsumerState<LessonPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _subjectCtrl = TextEditingController(text: 'Mathematics');
  final _topicCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController(text: 'Grade 1');
  final _objectivesCtrl = TextEditingController();
  final _materialsCtrl = TextEditingController();

  int _durationMinutes = 45;
  String _selectedLanguage = 'English';
  final Set<String> _selectedNeeds = {LearnerNeeds.mixedAbility};
  bool _showAdvanced = false;

  final List<String> _subjects = const [
    'Mathematics',
    'Science / EVS',
    'Language & Literacy',
    'Life Skills & Hygiene',
    'Social & Emotional Skills',
    'Art, Music & Sensory',
  ];

  final List<String> _grades = const [
    'Pre-Primary / Early Childhood',
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Middle School (6-8)',
  ];

  final List<String> _languages = const [
    'English',
    'Hindi',
    'Kannada',
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _topicCtrl.dispose();
    _gradeCtrl.dispose();
    _objectivesCtrl.dispose();
    _materialsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(lessonPlanProvider.notifier);
    await notifier.generate(
      subject: _subjectCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      grade: _gradeCtrl.text.trim(),
      durationMinutes: _durationMinutes,
      language: _selectedLanguage,
      learnerNeeds: _selectedNeeds.toList(),
      learningObjectives: _objectivesCtrl.text.trim(),
      materialsAvailable: _materialsCtrl.text.trim(),
    );

    final state = ref.read(lessonPlanProvider);
    if (!mounted) return;

    if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (state.lessonPlan != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LessonPlanResultScreen(plan: state.lessonPlan!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(lessonPlanProvider);
    final isGenerating = state.isGenerating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Lesson Plan'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: isGenerating
          ? _buildGeneratingState(theme)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Topic & Lesson Title
                  TextFormField(
                    controller: _topicCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Topic *',
                      hintText: 'e.g. Counting 1 to 10 with tactile objects',
                      prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please enter a lesson topic'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Subject Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _subjects.contains(_subjectCtrl.text)
                        ? _subjectCtrl.text
                        : _subjects.first,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: _subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _subjectCtrl.text = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Grade / Stage
                  DropdownButtonFormField<String>(
                    initialValue: _grades.contains(_gradeCtrl.text)
                        ? _gradeCtrl.text
                        : _grades.first,
                    decoration: const InputDecoration(
                      labelText: 'Grade / Learning Level *',
                      prefixIcon: Icon(Icons.auto_stories_outlined),
                    ),
                    items: _grades
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _gradeCtrl.text = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Duration Selector
                  Text(
                    'Lesson Duration',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 8,
                    children: [30, 40, 45, 60].map((mins) {
                      final isSelected = _durationMinutes == mins;
                      return ChoiceChip(
                        label: Text('$mins mins'),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _durationMinutes = mins),
                        selectedColor: theme.colorScheme.primaryContainer,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Language Selector
                  Text(
                    'Instruction Language',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 8,
                    children: _languages.map((lang) {
                      final isSelected = _selectedLanguage == lang;
                      return ChoiceChip(
                        label: Text(lang),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedLanguage = lang),
                        selectedColor: theme.colorScheme.primaryContainer,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Learner Needs Multi-Select
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Learner Needs & Accommodations',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_selectedNeeds.length} selected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Select the specific needs of students in your classroom to receive tailored instructional adjustments.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: LearnerNeeds.all.map((needKey) {
                      final label = LearnerNeeds.labels[needKey] ?? needKey;
                      final isSelected = _selectedNeeds.contains(needKey);
                      return FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (needKey == LearnerNeeds.none) {
                              _selectedNeeds.clear();
                              if (selected) _selectedNeeds.add(LearnerNeeds.none);
                            } else {
                              _selectedNeeds.remove(LearnerNeeds.none);
                              if (selected) {
                                _selectedNeeds.add(needKey);
                              } else {
                                _selectedNeeds.remove(needKey);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Collapsible Advanced Settings
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _showAdvanced
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Additional Classroom Details (Optional)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showAdvanced) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _objectivesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Specific Learning Objectives (Optional)',
                        hintText: 'e.g. Student can sort red blocks vs blue blocks',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _materialsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Available Classroom Materials (Optional)',
                        hintText: 'e.g. Sand tray, large wooden beads, number line',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),

                  // Generate Button
                  PrimaryButton(
                    label: 'Generate Lesson Plan',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }

  Widget _buildGeneratingState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Designing Differentiated Lesson Plan…',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Structuring timed instructional steps and matching evidence-based accommodations for your learners.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
