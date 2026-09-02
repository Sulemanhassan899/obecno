import 'package:obecno/demo/monotonic_clock/domain/demo_time_models.dart';

/// Offline queue for demo attendance events.
///
/// Timestamps are frozen on the event at creation time. Sync MUST send
/// [TrustedAttendanceEvent.timeSentToServer] as stored — never recalculate.
class DemoOfflineQueue {
  DemoOfflineQueue({List<TrustedAttendanceEvent>? pending})
      : _pending = List.of(pending ?? const []);

  final List<TrustedAttendanceEvent> _pending;

  List<TrustedAttendanceEvent> get pending => List.unmodifiable(_pending);

  bool get isEmpty => _pending.isEmpty;

  void enqueue(TrustedAttendanceEvent event) {
    _pending.add(event);
  }

  void replaceAll(List<TrustedAttendanceEvent> events) {
    _pending
      ..clear()
      ..addAll(events);
  }

  /// Returns queued events for upload without changing their timestamps.
  List<TrustedAttendanceEvent> peekForSync() => List.unmodifiable(_pending);

  /// Marks the given ids as synced and removes them from the queue.
  /// Does not recompute time.
  SyncResult markSynced(Iterable<String> ids) {
    final idSet = ids.toSet();
    final synced = _pending.where((e) => idSet.contains(e.id)).map((e) {
      return e.copyWith(synced: true);
    }).toList();
    _pending.removeWhere((e) => idSet.contains(e.id));
    return SyncResult(
      synced: synced,
      preservedTimestamps: synced.map((e) => e.timeSentToServer).toList(),
    );
  }

  void clear() => _pending.clear();
}
