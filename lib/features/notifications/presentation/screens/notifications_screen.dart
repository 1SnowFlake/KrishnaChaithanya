import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/utils/error_handler.dart';
import 'package:slkc_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:slkc_app/features/notifications/domain/models/notification_model.dart';
import 'package:slkc_app/features/notifications/presentation/providers/notification_provider.dart';

/// Screen displaying in-app alerts, missing-attendance notices, and administrative announcements.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsNotifierProvider);
    final user = ref.watch(authNotifierProvider).value;
    final isAdmin = user?.isAdmin ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications & Alerts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          // If Admin: On-demand Scan for Missing Attendance
          if (isAdmin) ...[
            IconButton(
              tooltip: 'Scan Missing Attendance Now',
              icon: const Icon(Icons.radar_outlined),
              onPressed: () async {
                try {
                  final created = await ref
                      .read(notificationsNotifierProvider.notifier)
                      .scanMissingAttendance(forceCheck: true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          created > 0
                              ? 'Scan completed: $created missing-attendance alert(s) dispatched!'
                              : 'Scan completed: All classes have submitted attendance.',
                        ),
                        backgroundColor: created > 0 ? Colors.orange : Colors.green,
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
            ),
          ],

          // Mark all as read
          IconButton(
            tooltip: 'Mark All as Read',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              await ref
                  .read(notificationsNotifierProvider.notifier)
                  .markAllAsRead();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to load notifications:\n${AppErrorHandler.getErrorMessage(e)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 56,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are all caught up!',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsNotifierProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _NotificationCard(item: item);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Visual card for an individual notification.
class _NotificationCard extends ConsumerWidget {
  final NotificationModel item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUnread = !item.isRead;
    final isMissingAlert = item.type == 'missing_attendance';

    final Color badgeColor = isMissingAlert ? Colors.orange.shade800 : Colors.blue;

    return Card(
      elevation: isUnread ? 1.5 : 0.4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnread
              ? badgeColor.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.2),
          width: isUnread ? 1.2 : 0.8,
        ),
      ),
      color: isUnread
          ? badgeColor.withValues(alpha: 0.04)
          : theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isUnread) {
            ref.read(notificationsNotifierProvider.notifier).markAsRead(item.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Icon
              CircleAvatar(
                radius: 18,
                backgroundColor: badgeColor.withValues(alpha: 0.15),
                child: Icon(
                  isMissingAlert ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: badgeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title, Message & Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.formattedTime,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                tooltip: 'Dismiss',
                onPressed: () {
                  ref
                      .read(notificationsNotifierProvider.notifier)
                      .deleteNotification(item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
