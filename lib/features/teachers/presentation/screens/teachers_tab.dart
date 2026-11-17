import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:slkc_app/features/teachers/domain/models/teacher_model.dart';
import 'package:slkc_app/features/teachers/presentation/providers/teacher_provider.dart';

/// Admin tab displaying all teachers and staff, with creation, edit,
/// role promotion (Admin ability), deactivation, and deletion controls.
class TeachersTab extends ConsumerWidget {
  const TeachersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersState = ref.watch(teachersNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: teachersState.when(
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
                onPressed: () => ref.read(teachersNotifierProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (teachers) {
          if (teachers.isEmpty) {
            return const Center(
              child: Text('No teachers found. Tap "+" to add a teacher.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(teachersNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: teachers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: teacher.isAdmin
                        ? theme.colorScheme.primaryContainer
                        : (teacher.isActive
                            ? theme.colorScheme.secondaryContainer
                            : theme.colorScheme.surfaceContainerHighest),
                    child: Icon(
                      teacher.isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: teacher.isAdmin
                          ? theme.colorScheme.primary
                          : (teacher.isActive
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.outline),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          teacher.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: teacher.isActive
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Role Badge: Shows specific staff role (Teacher, Warden, Cook, Aya, etc.)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: teacher.isAdmin
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: teacher.isAdmin
                                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              teacher.isAdmin
                                  ? Icons.security_rounded
                                  : Icons.badge_outlined,
                              size: 12,
                              color: teacher.isAdmin
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              teacher.role,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: teacher.isAdmin
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(teacher.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Active status switch
                      Switch.adaptive(
                        value: teacher.isActive,
                        onChanged: (val) async {
                          await ref
                              .read(teachersNotifierProvider.notifier)
                              .toggleStatus(teacher.id, val);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Teacher & Roles',
                        onPressed: () => _showEditDialog(context, ref, teacher),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        tooltip: 'Delete Teacher',
                        onPressed: () => _confirmDelete(context, ref, teacher),
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
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Staff'),
        onPressed: () => _showAddDialog(context, ref),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final customRoleCtrl = TextEditingController();
    String selectedRole = StaffRoles.teacher;
    bool isCustomRole = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Staff / Teacher'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Provisions a staff account for daily attendance & portal access.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter staff name' : null,
                  ),
                  const SizedBox(height: 12),
                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role / Designation',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    items: [
                      ...StaffRoles.presetRoles.map(
                        (r) => DropdownMenuItem(value: r, child: Text(r)),
                      ),
                      const DropdownMenuItem(
                        value: StaffRoles.other,
                        child: Text(StaffRoles.other),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedRole = val;
                          isCustomRole = val == StaffRoles.other;
                        });
                      }
                    },
                  ),
                  if (isCustomRole) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customRoleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enter Custom Role',
                        hintText: 'e.g. Librarian, Bus Driver, Peon',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter role name' : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Initial Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => v == null || v.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isSubmitting = true);
                      final finalRole = isCustomRole
                          ? customRoleCtrl.text.trim()
                          : selectedRole;
                      try {
                        await ref
                            .read(teachersNotifierProvider.notifier)
                            .createTeacher(
                              name: nameCtrl.text,
                              email: emailCtrl.text,
                              password: passCtrl.text,
                              role: finalRole,
                            );
                        if (context.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Staff member ($finalRole) created successfully!'),
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppErrorHandler.getErrorMessage(e)),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TeacherModel teacher) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: teacher.name);
    final customRoleCtrl = TextEditingController();
    bool isActive = teacher.isActive;
    bool isAdmin = teacher.isAdmin;
    final currentUserId = ref.read(authNotifierProvider).value?.id;
    final isSelf = currentUserId == teacher.id;
    final theme = Theme.of(context);

    // Initial role selection
    final isPreset = StaffRoles.presetRoles.contains(teacher.role);
    String selectedRole = isPreset ? teacher.role : StaffRoles.other;
    bool isCustomRole = !isPreset;
    if (isCustomRole) {
      customRoleCtrl.text = teacher.role;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Staff Details & Role'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role / Designation',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    items: [
                      ...StaffRoles.presetRoles.map(
                        (r) => DropdownMenuItem(value: r, child: Text(r)),
                      ),
                      const DropdownMenuItem(
                        value: StaffRoles.other,
                        child: Text(StaffRoles.other),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedRole = val;
                          isCustomRole = val == StaffRoles.other;
                          if (val == StaffRoles.admin) {
                            isAdmin = true;
                          }
                        });
                      }
                    },
                  ),
                  if (isCustomRole) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customRoleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enter Custom Role',
                        hintText: 'e.g. Librarian, Bus Driver',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter role name' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Active switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active Account'),
                    subtitle: const Text('Deactivated accounts cannot sign in.'),
                    value: isActive,
                    onChanged: (val) => setState(() => isActive = val),
                  ),
                  const Divider(),
                  // Admin Privileges switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: isAdmin
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    title: const Text('Admin Privileges'),
                    subtitle: Text(
                      isSelf
                          ? 'You cannot revoke your own admin rights.'
                          : (isAdmin
                              ? 'Enabled: Has full admin ability (attendance, reports, managing staff & classes).'
                              : 'Disabled: Standard staff permissions only.'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isAdmin
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: isAdmin,
                    onChanged: isSelf
                        ? null
                        : (val) {
                            setState(() {
                              isAdmin = val;
                              if (val) {
                                selectedRole = StaffRoles.admin;
                                isCustomRole = false;
                              }
                            });
                          },
                  ),
                ],
              ),
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
                final finalRole = isAdmin
                    ? StaffRoles.admin
                    : (isCustomRole ? customRoleCtrl.text.trim() : selectedRole);
                await ref.read(teachersNotifierProvider.notifier).updateTeacher(
                      id: teacher.id,
                      name: nameCtrl.text,
                      isActive: isActive,
                      role: finalRole,
                    );
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TeacherModel teacher) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('Delete Teacher'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${teacher.name}" (${teacher.email})?\n\n'
          'If this teacher has historical attendance records, they cannot be deleted and should be deactivated instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(teachersNotifierProvider.notifier)
                    .deleteTeacher(teacher.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Teacher "${teacher.name}" deleted.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  final errorMsg = AppErrorHandler.getErrorMessage(e);
                  final hasHistory = errorMsg.toLowerCase().contains('deactivate');

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: theme.colorScheme.error,
                      duration: const Duration(seconds: 5),
                      action: hasHistory
                          ? SnackBarAction(
                              label: 'Deactivate',
                              textColor: Colors.white,
                              onPressed: () {
                                ref
                                    .read(teachersNotifierProvider.notifier)
                                    .toggleStatus(teacher.id, false);
                              },
                            )
                          : null,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
