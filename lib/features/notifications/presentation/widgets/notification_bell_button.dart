import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:slkc_app/features/notifications/presentation/screens/notifications_screen.dart';

/// Reusable AppBar action button displaying a notification bell with an unread badge.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return IconButton(
      tooltip: 'Notifications ($unreadCount unread)',
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          unreadCount > 9 ? '9+' : '$unreadCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
    );
  }
}
