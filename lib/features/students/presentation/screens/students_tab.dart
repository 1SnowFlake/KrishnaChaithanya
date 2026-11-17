import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/classes/domain/models/class_model.dart';
import 'package:slkc_app/features/classes/presentation/providers/class_provider.dart';
import 'package:slkc_app/features/students/domain/models/student_model.dart';
import 'package:slkc_app/features/students/presentation/providers/student_provider.dart';

/// Admin tab displaying students with filtering by class, CRUD dialogs,
/// and CSV bulk import capabilities.
class StudentsTab extends ConsumerWidget {
  const StudentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsState = ref.watch(studentsNotifierProvider);
    final classes = ref.watch(classesNotifierProvider).value ?? [];
    final selectedClassId = ref.watch(selectedClassFilterProvider);
    final theme = Theme.of(context);

    // Safeguard: Ensure the selected value exists in the classes list,
    // otherwise fallback to null (All Classes) to prevent Dropdown crash.
    final effectiveClassFilter = (selectedClassId != null &&
            classes.any((c) => c.id == selectedClassId))
        ? selectedClassId
        : null;

    return Scaffold(
      body: Column(
        children: [
          // Filter & Actions Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('filter_${effectiveClassFilter}_${classes.length}'),
                    decoration: const InputDecoration(
                      labelText: 'Filter by Class',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: effectiveClassFilter,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Classes'),
                      ),
                      ...classes.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      ref.read(studentsNotifierProvider.notifier).filterByClass(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Import Students from CSV',
                  icon: const Icon(Icons.upload_file_rounded),
                  onPressed: () => _pickAndImportCsv(context, ref, classes),
                ),
              ],
            ),
          ),

          // Student List View
          Expanded(
            child: studentsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppErrorHandler.getErrorMessage(err),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.read(studentsNotifierProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (students) {
                if (students.isEmpty) {
                  return const Center(
                    child: Text('No students found. Tap "+" or import a CSV.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(studentsNotifierProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: student.isActive
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Text(
                            student.rollNo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: student.isActive
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        title: Text(
                          student.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: student.isActive
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          'Class: ${student.className ?? 'Unknown'} • Roll: ${student.rollNo}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit Student',
                              onPressed: () =>
                                  _showEditDialog(context, ref, student, classes),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete Student',
                              onPressed: () => _confirmDelete(context, ref, student),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Student'),
        onPressed: () => _showAddDialog(context, ref, classes),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, List<ClassModel> classes) {
    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create at least one class first.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    String selectedClassId = ref.read(selectedClassFilterProvider) ?? classes.first.id;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Student'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Class'),
                  value: selectedClassId,
                  items: classes
                      .map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedClassId = val!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rollCtrl,
                  decoration: const InputDecoration(labelText: 'Roll Number'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter roll number' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Student Full Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter name' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ref.read(studentsNotifierProvider.notifier).createStudent(
                        name: nameCtrl.text,
                        rollNo: rollCtrl.text,
                        classId: selectedClassId,
                      );
                  if (context.mounted) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Student added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppErrorHandler.getErrorMessage(e)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    StudentModel student,
    List<ClassModel> classes,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: student.name);
    final rollCtrl = TextEditingController(text: student.rollNo);
    String selectedClassId = student.classId;
    bool isActive = student.isActive;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Student'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Class'),
                  value: selectedClassId,
                  items: classes
                      .map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedClassId = val!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rollCtrl,
                  decoration: const InputDecoration(labelText: 'Roll Number'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter roll number' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active Student'),
                  value: isActive,
                  onChanged: (val) => setState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ref.read(studentsNotifierProvider.notifier).updateStudent(
                        id: student.id,
                        name: nameCtrl.text,
                        rollNo: rollCtrl.text,
                        classId: selectedClassId,
                        isActive: isActive,
                      );
                  if (context.mounted) Navigator.pop(dialogCtx);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppErrorHandler.getErrorMessage(e)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, StudentModel student) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete "${student.name}"?'),
        content: const Text(
          'This will permanently delete this student record and their attendance history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref
                  .read(studentsNotifierProvider.notifier)
                  .deleteStudent(student.id);
              if (context.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportCsv(
    BuildContext context,
    WidgetRef ref,
    List<ClassModel> classes,
  ) async {
    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a class before importing students.')),
      );
      return;
    }

    // Step 1: Select target class
    String targetClassId =
        ref.read(selectedClassFilterProvider) ?? classes.first.id;

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Students from CSV'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select the class to import students into:\n\n'
                'Expected CSV format:\n'
                'name,roll_no\n'
                'Aarav Kumar,1\n'
                'Diya Singh,2',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Target Class'),
                value: targetClassId,
                items: classes
                    .map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (val) => setState(() => targetClassId = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, targetClassId),
              child: const Text('Choose CSV File'),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;

    // Step 2: Open file picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String csvString;
    if (file.bytes != null) {
      csvString = utf8.decode(file.bytes!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file data.')),
      );
      return;
    }

    // Step 3: Run bulk import
    try {
      final importResult = await ref
          .read(studentsNotifierProvider.notifier)
          .importFromCsv(classId: selected, csvContent: csvString);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Import Summary'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Successfully imported: ${importResult.successCount} of ${importResult.totalRows} students.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (importResult.errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Errors / Skipped:',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ...importResult.errors.map(
                      (e) => Text('• $e', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.getErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
