import 'dart:async';

import 'package:Obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:Obecno/shared/location/service/local_queue_service.dart';

import '../repositories/clock_attendance_repository.dart';

/// Listens for connectivity changes and, the moment the connection
/// comes back, automatically replays every unsynced record in the
/// offline queue, oldest first.
///
/// - Guards against overlapping syncs with [_isSyncing] (e.g. two
///   connectivity events firing close together).
/// - Stops the FIFO replay on the first failed record (per spec) rather
///   than retrying/skipping -- the next connectivity event (or a manual
///   [syncPendingData] call) will pick back up from that same record.
class SyncService {
  SyncService(this._repository, this._connectivityService, this._queueService);

  final AttendanceRepository _repository;
  final AttendanceConnectivityService _connectivityService;
  final LocalQueueService _queueService;

  StreamSubscription<bool>? _subscription;
  bool _isSyncing = false;

  /// Call once (e.g. from wherever `AttendanceProvider` is created) to
  /// start auto-syncing on reconnect.
  void startListening() {
    _subscription?.cancel();
    _subscription = _connectivityService.onConnectivityChanged.listen((online) {
      if (online) {
        unawaited(syncPendingData());
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Sends every unsynced queued record, oldest first. Safe to call
  /// manually (e.g. app resume) in addition to the automatic
  /// connectivity-triggered sync.
  Future<void> syncPendingData() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = await _queueService.getPending();

      for (final item in pending) {
        try {
          await _repository.sendQueuedPayload(item.payload);
          await _queueService.markSynced(item.id);
        } catch (_) {
          // Stop on first failure, as specified -- avoids hammering a
          // still-flaky connection with the rest of the queue.
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() => stopListening();
}
