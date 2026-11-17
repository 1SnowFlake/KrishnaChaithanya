import 'package:flutter/material.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/students/domain/models/student_model.dart';

/// Confirmation dialog shown before submitting attendance.
/// Displays total counts and lists all absent students for verification.
/// Manages its own submission state to prevent double-pop navigation crashes.
class AttendanceConfirmDialog extends StatefulWidget {
  final String className;
  final String session;
  final int totalCount;
  final int presentCount;
  final int absentCount;
  final List<StudentModel> absentStudents;
  final Future<void> Function() onConfirm;

  const AttendanceConfirmDialog({
    super.key,
    required this.className,
    required this.session,
    required this.totalCount,
    required this.presentCount,
    required this.absentCount,
    required this.absentStudents,
    required this.onConfirm,
  });

  @override
  State<AttendanceConfirmDialog> createState() => _AttendanceConfirmDialogState();
}

class _AttendanceConfirmDialogState extends State<AttendanceConfirmDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final capitalizedSession = widget.session[0].toUpperCase() +
        widget.session.substring(1).toLowerCase();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Confirm Submission'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.className} • $capitalizedSession Session',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Statistics Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${widget.presentCount}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text(
                          'Present',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${widget.absentCount}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const Text(
                          'Absent',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Absentees List for explicit review
            if (widget.absentStudents.isNotEmpty) ...[
              const Text(
                'Absent Students to be marked:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.absentStudents.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = widget.absentStudents[index];
                    return Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Roll ${s.rollNo}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'All students are marked Present!',
                      style: TextStyle(color: Colors.green, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Text(
              'Submitted attendance can be edited today only, prior to session cutoff.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Go Back'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() {
                    _isSubmitting = true;
                    _errorMessage = null;
                  });

                  try {
                    await widget.onConfirm();
                    if (context.mounted) {
                      Navigator.pop(context, true); // Success
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isSubmitting = false;
                        _errorMessage = AppErrorHandler.getErrorMessage(e);
                      });
                    }
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm & Submit'),
        ),
      ],
    );
  }
}
