import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/classes/domain/models/class_model.dart';
import 'package:slkc_app/features/classes/presentation/providers/class_provider.dart';
import 'package:slkc_app/features/teachers/presentation/providers/teacher_provider.dart';

/// Admin tab displaying all school classes, with creation, assignment, and deletion.
class ClassesTab extends ConsumerWidget {
  const ClassesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesState = ref.watch(classesNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: classesState.when(
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
                onPressed: () => ref.read(classesNotifierProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return const Center(
              child: Text('No classes found. Tap "+" to create a class.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(classesNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: classes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final cls = classes[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      cls.name.isNotEmpty ? cls.name[0].toUpperCase() : 'C',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    cls.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Teacher: ${cls.primaryTeacherName ?? 'Not Assigned'} • ${cls.studentCount} Students',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Class',
                        onPressed: () => _showEditDialog(context, ref, cls),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete Class',
                        onPressed: () => _confirmDelete(context, ref, cls),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Class'),
        onPressed: () => _showAddDialog(context, ref),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    String? selectedTeacherId;
    final teachers = ref.read(teachersNotifierProvider).value ?? [];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Class'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Class Name (e.g. Class 3-A)',
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter class name' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Primary Teacher',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  value: selectedTeacherId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...teachers.map(
                      (t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text('${t.name} (${t.email})'),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => selectedTeacherId = val),
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
                  await ref.read(classesNotifierProvider.notifier).createClass(
                        name: nameCtrl.text,
                        primaryTeacherId: selectedTeacherId,
                      );
                  if (context.mounted) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Class added successfully!'),
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

  void _showEditDialog(BuildContext context, WidgetRef ref, ClassModel cls) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: cls.name);
    String? selectedTeacherId = cls.primaryTeacherId;
    final teachers = ref.read(teachersNotifierProvider).value ?? [];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Class'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Class Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter class name' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(labelText: 'Primary Teacher'),
                  value: selectedTeacherId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...teachers.map(
                      (t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(t.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => selectedTeacherId = val),
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
                await ref.read(classesNotifierProvider.notifier).updateClass(
                      id: cls.id,
                      name: nameCtrl.text,
                      primaryTeacherId: selectedTeacherId,
                    );
                if (context.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ClassModel cls) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete "${cls.name}"?'),
        content: const Text(
          'Deleting this class will also delete all students and attendance associated with it. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(classesNotifierProvider.notifier).deleteClass(cls.id);
              if (context.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
