import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

/// Local archive of leave alerts — pending + reviewed stay forever.
///
/// [namespace] separates manager inbox (`manager`) from employee decision
/// cards (`employee`) so role switches do not mix archives.
class LeaveAlertStore {
  LeaveAlertStore({
    FlutterSecureStorage? storage,
    String namespace = 'manager',
  }) : _storage = storage ?? const FlutterSecureStorage(),
       // Manager keeps legacy keys so existing archives survive upgrades.
       _key = namespace == 'manager'
           ? 'alerts_leave_archive_v1'
           : 'alerts_leave_archive_${namespace}_v1',
       _notifiedKey = namespace == 'manager'
           ? 'alerts_leave_notified_keys_v1'
           : 'alerts_leave_notified_${namespace}_v1';

  final FlutterSecureStorage _storage;
  final String _key;
  final String _notifiedKey;
  final Map<String, ManagerTeamLeaveItem> _byKey = {};
  final Set<String> _notifiedKeys = {};
  bool _loaded = false;

  List<ManagerTeamLeaveItem> get items {
    final list = _byKey.values.toList(growable: false);
    list.sort((a, b) {
      final aPend = a.isPendingInInbox ? 0 : 1;
      final bPend = b.isPendingInInbox ? 0 : 1;
      if (aPend != bPend) return aPend.compareTo(bPend);
      // Newest requests first (requested_at / id), then leave start date.
      final byTime = b.alertSortTime.compareTo(a.alertSortTime);
      if (byTime != 0) return byTime;
      final aId = a.id ?? 0;
      final bId = b.id ?? 0;
      if (aId != bId) return bId.compareTo(aId);
      return 0;
    });
    return list;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final row in decoded) {
            if (row is! Map) continue;
            final item = ManagerTeamLeaveItem.fromJson(
              Map<String, dynamic>.from(row),
            );
            _byKey[item.alertKey] = item;
          }
        }
      }
      final notifiedRaw = await _storage.read(key: _notifiedKey);
      if (notifiedRaw != null && notifiedRaw.isNotEmpty) {
        final decoded = jsonDecode(notifiedRaw);
        if (decoded is List) {
          _notifiedKeys.addAll(decoded.map((e) => e.toString()));
        }
      }
    } catch (e, st) {
      AppLogger.error('LeaveAlertStore', 'load', e, stackTrace: st);
    }
    _loaded = true;
  }

  bool wasNotified(String key) => _notifiedKeys.contains(key);

  Future<void> markNotified(String key) async {
    await load();
    if (key.trim().isEmpty || _notifiedKeys.contains(key)) return;
    _notifiedKeys.add(key);
    await _writeNotified();
  }

  /// Upsert live pending rows; keep reviewed rows that are no longer pending.
  Future<List<ManagerTeamLeaveItem>> mergePending(
    Iterable<ManagerTeamLeaveItem> pending,
  ) async {
    await load();
    final pendingKeys = <String>{};
    for (final item in pending) {
      if (!item.isPendingInInbox) continue;
      final key = item.alertKey;
      pendingKeys.add(key);
      final existing = _byKey[key];
      // Don't overwrite a locally reviewed status with a stale pending payload.
      if (existing != null &&
          !existing.isPendingInInbox &&
          (existing.countsAsOnLeave || existing.isRejectedLeave)) {
        continue;
      }
      _byKey[key] = item;
    }
    await _persist();
    return items;
  }

  /// Upsert decided (approved / rejected) rows for the Alerts inbox.
  ///
  /// [assumeApproved] / [assumeRejected]: when the API was already scoped to
  /// that status, blank status payloads still count (same as overview).
  Future<List<ManagerTeamLeaveItem>> mergeDecided(
    Iterable<ManagerTeamLeaveItem> decided, {
    bool assumeApproved = false,
    bool assumeRejected = false,
  }) async {
    await load();
    for (final item in decided) {
      var row = item;
      if (assumeRejected && !row.isRejectedLeave) {
        row = row.copyWith(status: 'rejected', statusLabel: 'Rejected');
      } else if (assumeApproved &&
          !row.countsAsOnLeave &&
          !row.isRejectedLeave) {
        row = row.copyWith(status: 'approved', statusLabel: 'Approved');
      }
      if (row.isPendingInInbox) continue;
      if (!row.countsAsOnLeave && !row.isRejectedLeave) continue;
      // Keep a locally newer requestedAt if the API omits it.
      final existing = _byKey[row.alertKey];
      if (existing != null &&
          (row.requestedAt == null || row.requestedAt!.trim().isEmpty) &&
          (existing.requestedAt ?? '').trim().isNotEmpty) {
        row = row.copyWith(requestedAt: existing.requestedAt);
      }
      _byKey[row.alertKey] = row;
    }
    await _persist();
    return items;
  }

  Future<void> upsert(ManagerTeamLeaveItem item) async {
    await load();
    _byKey[item.alertKey] = item;
    await _persist();
  }

  Future<void> markReviewed({
    required String key,
    required String action,
  }) async {
    await load();
    final existing = _byKey[key];
    if (existing == null) return;
    final approved = action == 'approve';
    _byKey[key] = existing.copyWith(
      status: approved ? 'approved' : 'rejected',
      statusLabel: approved ? 'Approved' : 'Rejected',
    );
    await _persist();
  }

  /// Drop in-memory state so the next [load] re-reads disk.
  /// Does **not** delete the persisted archive (survives auth flicker / restart).
  void unload() {
    _byKey.clear();
    _notifiedKeys.clear();
    _loaded = false;
  }

  /// Wipe memory + secure storage (real logout / account switch only).
  Future<void> clear() async {
    _byKey.clear();
    _notifiedKeys.clear();
    _loaded = true;
    try {
      await _storage.delete(key: _key);
      await _storage.delete(key: _notifiedKey);
    } catch (e, st) {
      AppLogger.error('LeaveAlertStore', 'clear', e, stackTrace: st);
    }
  }

  Future<void> _persist() async {
    try {
      final payload = _byKey.values.map((e) => e.toJson()).toList();
      await _storage.write(key: _key, value: jsonEncode(payload));
    } catch (e, st) {
      AppLogger.error('LeaveAlertStore', 'persist', e, stackTrace: st);
    }
  }

  Future<void> _writeNotified() async {
    try {
      await _storage.write(
        key: _notifiedKey,
        value: jsonEncode(_notifiedKeys.toList()),
      );
    } catch (e, st) {
      AppLogger.error('LeaveAlertStore', 'writeNotified', e, stackTrace: st);
    }
  }
}
