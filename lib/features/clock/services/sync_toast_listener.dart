import 'dart:async';

import 'package:obecno/features/clock/services/sync_service.dart';

/// Shows "Syncing" then "Synced" whenever queued attendance is actually
/// pushed. Independent of ClockScreen so toasts still appear when the user
/// is on another tab or has just left Settings after turning the network on.
class SyncToastListener {
  SyncToastListener({
    required this.onSyncing,
    required this.onSynced,
    this.minSyncingVisible = const Duration(milliseconds: 1000),
  });

  final void Function() onSyncing;
  final void Function({required bool success}) onSynced;
  final Duration minSyncingVisible;

  DateTime? _syncingShownAt;
  Timer? _syncedTimer;

  void attach(SyncService sync) {
    sync.onStateChanged = handle;
  }

  void handle(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        _syncedTimer?.cancel();
        _syncingShownAt = DateTime.now();
        onSyncing();
      case SyncState.success:
      case SyncState.failure:
        _scheduleSynced(success: state == SyncState.success);
      case SyncState.idle:
        break;
    }
  }

  void _scheduleSynced({required bool success}) {
    _syncedTimer?.cancel();
    final shownAt = _syncingShownAt;
    final elapsed = shownAt == null
        ? minSyncingVisible
        : DateTime.now().difference(shownAt);
    final delay = elapsed >= minSyncingVisible
        ? Duration.zero
        : minSyncingVisible - elapsed;
    _syncedTimer = Timer(delay, () {
      _syncedTimer = null;
      onSynced(success: success);
    });
  }

  void dispose() {
    _syncedTimer?.cancel();
    _syncedTimer = null;
  }
}
