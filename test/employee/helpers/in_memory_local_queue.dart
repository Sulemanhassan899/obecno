import 'dart:async';

import 'package:Obecno/shared/location/data/queue_model.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:Obecno/shared/location/service/local_queue_service.dart';

/// In-memory queue for employee offline punch tests (no SQLite / no app code changes).
class InMemoryLocalQueue implements LocalQueueService {
  final List<_Row> _rows = [];
  int _nextId = 1;

  String? currentUserId;

  @override
  Future<bool> insert(AttendancePayloadModel payload) async {
    if (currentUserId == null || currentUserId!.isEmpty) return false;
    _rows.add(
      _Row(
        id: _nextId++,
        userId: currentUserId!,
        payload: payload,
        isSynced: false,
        retryCount: 0,
        isDeadLetter: false,
      ),
    );
    return true;
  }

  @override
  Future<List<QueueModel>> getPending() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    return _rows
        .where((r) => r.userId == uid && !r.isSynced && !r.isDeadLetter)
        .map(
          (r) => QueueModel(id: r.id, payload: r.payload, isSynced: r.isSynced),
        )
        .toList();
  }

  @override
  Future<void> markSynced(int id) async {
    final row = _rows.cast<_Row?>().firstWhere(
      (r) => r?.id == id,
      orElse: () => null,
    );
    if (row != null) row.isSynced = true;
  }

  @override
  Future<int> recordFailure(int id) async {
    final row = _rows.cast<_Row?>().firstWhere(
      (r) => r?.id == id,
      orElse: () => null,
    );
    if (row == null) return 1;
    row.retryCount++;
    return row.retryCount;
  }

  @override
  Future<void> resetFailure(int id) async {
    final row = _rows.cast<_Row?>().firstWhere(
      (r) => r?.id == id,
      orElse: () => null,
    );
    if (row != null) row.retryCount = 0;
  }

  @override
  Future<void> markDeadLetter(int id) async {
    final row = _rows.cast<_Row?>().firstWhere(
      (r) => r?.id == id,
      orElse: () => null,
    );
    if (row != null) row.isDeadLetter = true;
  }

  @override
  Future<void> clearAll() async => _rows.clear();

  @override
  Future<int> getDeadLetterCount() async {
    final uid = currentUserId;
    if (uid == null) return 0;
    return _rows.where((r) => r.userId == uid && r.isDeadLetter).length;
  }

  @override
  Future<bool> retryDeadLetter(int id) async {
    final row = _rows.cast<_Row?>().firstWhere(
      (r) => r?.id == id,
      orElse: () => null,
    );
    if (row == null || !row.isDeadLetter) return false;
    row.isDeadLetter = false;
    row.retryCount = 0;
    row.isSynced = false;
    return true;
  }
}

class _Row {
  _Row({
    required this.id,
    required this.userId,
    required this.payload,
    required this.isSynced,
    required this.retryCount,
    required this.isDeadLetter,
  });

  final int id;
  final String userId;
  final AttendancePayloadModel payload;
  bool isSynced;
  int retryCount;
  bool isDeadLetter;
}
