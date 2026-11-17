import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/supabase/supabase_config.dart';
import 'package:slkc_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:slkc_app/features/notifications/domain/models/notification_model.dart';

/// Provides the [NotificationRepository].
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(SupabaseConfig.client);
});

/// Async notifier managing the list of visible notifications for the active user.
class NotificationsNotifier
    extends AsyncNotifier<List<NotificationModel>> {
  late final NotificationRepository _repo;

  @override
  FutureOr<List<NotificationModel>> build() {
    _repo = ref.watch(notificationRepositoryProvider);
    return _repo.getNotifications();
  }

  /// Reloads notifications from Supabase.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getNotifications());
  }

  /// Marks a specific notification as read with optimistic UI update.
  Future<void> markAsRead(String id) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
      );
    }
    await _repo.markAsRead(id);
    await refresh();
  }

  /// Marks all visible unread notifications as read.
  Future<void> markAllAsRead() async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.map((n) => n.copyWith(isRead: true)).toList(),
      );
    }
    await _repo.markAllAsRead();
    await refresh();
  }

  /// Deletes a notification.
  Future<void> deleteNotification(String id) async {
    await _repo.deleteNotification(id);
    await refresh();
  }

  /// Triggers a live missing-attendance scan and refreshes notifications.
  Future<int> scanMissingAttendance({bool forceCheck = false}) async {
    final count = await _repo.scanMissingAttendance(forceCheck: forceCheck);
    await refresh();
    return count;
  }
}

final notificationsNotifierProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
  NotificationsNotifier.new,
);

/// Computed provider for unread notifications count (used for badge counters).
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsNotifierProvider).value ?? [];
  return notifs.where((n) => !n.isRead).length;
});
