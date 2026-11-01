import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:obecno/core/services/logger.dart';

/// Offline queue for leave apply / update actions.
///
/// Mirrors attendance punch queueing: actions are stored locally and flushed
/// automatically when connectivity returns.
class LeaveQueueService {
  LeaveQueueService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String userId) => 'leave_module_queue_$userId';

  Future<List<LeaveQueuedAction>> getPending(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => LeaveQueuedAction.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e, st) {
      AppLogger.error('LeaveQueueService', 'getPending', e, stackTrace: st);
      return const [];
    }
  }

  Future<bool> enqueue(String userId, LeaveQueuedAction action) async {
    if (userId.isEmpty) return false;
    try {
      final pending = [...await getPending(userId)];
      final index = pending.indexWhere((a) => a.localId == action.localId);
      if (index >= 0) {
        pending[index] = action;
      } else {
        pending.add(action);
      }
      await _write(userId, pending);
      AppLogger.info(
        'LEAVE QUEUE ENQUEUED\n'
        'Action: ${action.action}\n'
        'LocalId: ${action.localId}\n'
        'TypeId: ${action.typeId}\n'
        'Dates: ${action.startDate} → ${action.endDate}',
      );
      return true;
    } catch (e, st) {
      AppLogger.error('LeaveQueueService', 'enqueue', e, stackTrace: st);
      return false;
    }
  }

  Future<void> remove(String userId, String localId) async {
    if (userId.isEmpty || localId.isEmpty) return;
    try {
      final pending = await getPending(userId);
      final next = pending.where((a) => a.localId != localId).toList();
      await _write(userId, next);
    } catch (e, st) {
      AppLogger.error('LeaveQueueService', 'remove', e, stackTrace: st);
    }
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _storage.delete(key: _key(userId));
    } catch (e, st) {
      AppLogger.error('LeaveQueueService', 'clear', e, stackTrace: st);
    }
  }

  Future<void> _write(String userId, List<LeaveQueuedAction> items) async {
    await _storage.write(
      key: _key(userId),
      value: jsonEncode([for (final a in items) a.toJson()]),
    );
  }
}

enum LeaveQueueActionType { apply, update }

class LeaveQueuedAction {
  const LeaveQueuedAction({
    required this.localId,
    required this.action,
    required this.typeId,
    required this.startDate,
    required this.endDate,
    required this.note,
    required this.createdAt,
    this.typeName,
    this.documentName,
    this.leaveId,
  });

  final String localId;
  final LeaveQueueActionType action;
  final String typeId;
  final String? typeName;
  final DateTime startDate;
  final DateTime endDate;
  final String note;
  final String? documentName;
  final String? leaveId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'action': action.name,
        'type_id': typeId,
        if (typeName != null) 'type_name': typeName,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'note': note,
        if (documentName != null) 'document_name': documentName,
        if (leaveId != null) 'leave_id': leaveId,
        'created_at': createdAt.toIso8601String(),
      };

  factory LeaveQueuedAction.fromJson(Map<String, dynamic> json) {
    final actionRaw = (json['action'] as String? ?? 'apply').toLowerCase();
    return LeaveQueuedAction(
      localId: (json['local_id'] as String?) ?? '',
      action: actionRaw == 'update'
          ? LeaveQueueActionType.update
          : LeaveQueueActionType.apply,
      typeId: (json['type_id'] as String?) ?? '',
      typeName: json['type_name'] as String?,
      startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] as String? ?? '') ??
          DateTime.now(),
      note: (json['note'] as String?) ?? '',
      documentName: json['document_name'] as String?,
      leaveId: json['leave_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
