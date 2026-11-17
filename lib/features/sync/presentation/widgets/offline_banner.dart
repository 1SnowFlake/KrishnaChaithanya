import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slkc_app/core/theme/app_theme.dart';
import '../providers/sync_provider.dart';

/// A slim, non-blocking connectivity + sync status chip shown at the
/// top of Teacher and Attendance screens.
///
/// - Hidden when online with no pending items.
/// - Offline: amber/orange banner.
/// - Online + pending / syncing: blue banner with Sync Now action.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline    = ref.watch(isOnlineProvider);
    final pendingCount = ref.watch(outboxCountProvider);
    final syncState   = ref.watch(syncActionProvider);

    // Hidden when everything is clean
    if (isOnline && pendingCount == 0 && !syncState.isLoading) {
      return const SizedBox.shrink();
    }

    if (!isOnline) {
      return _BannerStrip(
        color: AppColors.offline,
        icon: Icons.wifi_off_rounded,
        message: pendingCount > 0
            ? 'Offline · $pendingCount record${pendingCount == 1 ? "" : "s"} queued to sync'
            : 'Offline · Attendance saved locally',
      );
    }

    final isSyncing = syncState.isLoading;
    return _BannerStrip(
      color: AppColors.syncing,
      icon: isSyncing ? Icons.sync_rounded : Icons.cloud_upload_outlined,
      spinning: isSyncing,
      message: isSyncing
          ? 'Syncing attendance to server…'
          : 'Back online · $pendingCount pending change${pendingCount == 1 ? "" : "s"}',
      action: (!isSyncing && pendingCount > 0)
          ? _SyncNowButton(onTap: () =>
              ref.read(syncActionProvider.notifier).triggerSync())
          : null,
    );
  }
}

class _BannerStrip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  final bool spinning;
  final Widget? action;

  const _BannerStrip({
    required this.color,
    required this.icon,
    required this.message,
    this.spinning = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: color,
      child: Row(
        children: [
          spinning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _SyncNowButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SyncNowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(44, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          decoration: TextDecoration.underline,
        ),
      ),
      child: const Text('SYNC NOW'),
    );
  }
}
