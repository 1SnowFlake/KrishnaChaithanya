import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/app_local_database.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/sync_engine.dart';

/// Provides the local SQLite database instance.
final localDatabaseProvider = Provider<AppLocalDatabase>((ref) {
  final db = AppLocalDatabase();
  // Ensure DB is initialized
  db.init();
  ref.onDispose(() => db.dispose());
  return db;
});

/// Provides the network connectivity monitoring service.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of connectivity status (true = online, false = offline).
final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Current connectivity state (defaults to online until proven otherwise).
final isOnlineProvider = Provider<bool>((ref) {
  final asyncVal = ref.watch(isOnlineStreamProvider);
  return asyncVal.value ?? true;
});

/// StateNotifier tracking pending outbox items count.
class OutboxCountNotifier extends StateNotifier<int> {
  final AppLocalDatabase _db;

  OutboxCountNotifier(this._db) : super(0) {
    refresh();
  }

  void refresh() {
    state = _db.getPendingOutboxCount();
  }
}

final outboxCountProvider =
    StateNotifierProvider<OutboxCountNotifier, int>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return OutboxCountNotifier(db);
});

/// Provides the [SyncEngine] instance.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final conn = ref.watch(connectivityServiceProvider);
  final engine = SyncEngine(localDb: db, connectivity: conn);

  // Auto-sync when connectivity transitions to online
  ref.listen<bool>(isOnlineProvider, (prev, isNowOnline) {
    if (isNowOnline) {
      engine.syncPendingOutbox().then((_) {
        ref.read(outboxCountProvider.notifier).refresh();
      });
    }
  });

  return engine;
});

/// State for active manual sync action (loading, result message).
class SyncStateNotifier extends StateNotifier<AsyncValue<SyncResult?>> {
  final SyncEngine _engine;
  final Ref _ref;

  SyncStateNotifier(this._engine, this._ref) : super(const AsyncData(null));

  Future<SyncResult> triggerSync() async {
    state = const AsyncLoading();
    try {
      final result = await _engine.syncPendingOutbox();
      _ref.read(outboxCountProvider.notifier).refresh();
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final syncActionProvider =
    StateNotifierProvider<SyncStateNotifier, AsyncValue<SyncResult?>>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return SyncStateNotifier(engine, ref);
});
