import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service monitoring network connectivity state changes.
class ConnectivityService {
  final Connectivity _connectivity;
  final StreamController<bool> _isOnlineController = StreamController<bool>.broadcast();

  ConnectivityService({Connectivity? connectivity, bool autoListen = true})
      : _connectivity = connectivity ?? Connectivity() {
    if (autoListen) {
      _init();
    }
  }

  void _init() {
    try {
      _connectivity.onConnectivityChanged.listen(
        (results) {
          final isOnline = _isResultsOnline(results);
          if (!_isOnlineController.isClosed) {
            _isOnlineController.add(isOnline);
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // In test/headless environments without platform channels
    }
  }

  bool _isResultsOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Checks current connectivity (defaults to true if running in tests/headless without platform channel).
  Future<bool> checkOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _isResultsOnline(results);
    } catch (_) {
      // Return true in tests / desktop headless where platform channels are unmocked
      return true;
    }
  }

  /// Broadcast stream of connectivity changes (true = online, false = offline).
  Stream<bool> get onConnectivityChanged => _isOnlineController.stream;

  void dispose() {
    _isOnlineController.close();
  }
}
