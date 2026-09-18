import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:obecno/core/services/logger.dart';

/// Persists one-shot alert state so approved device cards (and similar)
/// appear when a notification fires, then disappear after the user opens Alerts.
class AlertSeenStore {
  AlertSeenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _seenKey = 'alerts_seen_device_keys';
  static const _oneshotKey = 'alerts_oneshot_device_keys';
  static const _statusKey = 'alerts_last_employee_device_status';
  static const _noticeKey = 'alerts_employee_approval_notice_key';
  static const _migratedKey = 'alerts_seen_migrated_v1';

  final FlutterSecureStorage _storage;
  Set<String> _seen = {};
  Set<String> _oneshot = {};
  String? _lastEmployeeStatus;
  String? _employeeApprovalNoticeKey;
  bool _migrated = false;
  bool _loaded = false;

  Set<String> get oneshotKeys => _oneshot;
  String? get lastEmployeeStatus => _lastEmployeeStatus;
  bool get isMigrated => _migrated;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final seenRaw = await _storage.read(key: _seenKey);
      if (seenRaw != null && seenRaw.isNotEmpty) {
        final decoded = jsonDecode(seenRaw);
        if (decoded is List) {
          _seen = decoded.map((e) => e.toString()).toSet();
        }
      }
      final oneshotRaw = await _storage.read(key: _oneshotKey);
      if (oneshotRaw != null && oneshotRaw.isNotEmpty) {
        final decoded = jsonDecode(oneshotRaw);
        if (decoded is List) {
          _oneshot = decoded.map((e) => e.toString()).toSet();
        }
      }
      _lastEmployeeStatus = await _storage.read(key: _statusKey);
      _employeeApprovalNoticeKey = await _storage.read(key: _noticeKey);
      _migrated = (await _storage.read(key: _migratedKey)) == '1';
    } catch (e, st) {
      AppLogger.error('AlertSeenStore', 'load', e, stackTrace: st);
    }
    _loaded = true;
  }

  bool contains(String key) => _seen.contains(key);

  bool isOneshot(String key) => _oneshot.contains(key);

  Future<void> markSeen(Iterable<String> keys) async {
    await load();
    final next = {..._seen, ...keys.where((k) => k.trim().isNotEmpty)};
    final oneshotNext = {..._oneshot}..removeAll(keys);
    if (next.length == _seen.length &&
        next.containsAll(_seen) &&
        oneshotNext.length == _oneshot.length) {
      return;
    }
    _seen = next;
    _oneshot = oneshotNext;
    await _writeSet(_seenKey, _seen);
    await _writeSet(_oneshotKey, _oneshot);
  }

  Future<void> addOneshot(String key) async {
    await load();
    if (key.trim().isEmpty || _oneshot.contains(key) || _seen.contains(key)) {
      return;
    }
    _oneshot = {..._oneshot, key};
    await _writeSet(_oneshotKey, _oneshot);
  }

  bool alreadyNotifiedEmployeeApproval(String key) {
    final value = key.trim();
    return value.isNotEmpty && _employeeApprovalNoticeKey == value;
  }

  Future<void> markEmployeeApprovalNotified(String key) async {
    await load();
    final value = key.trim();
    if (value.isEmpty || _employeeApprovalNoticeKey == value) return;
    _employeeApprovalNoticeKey = value;
    try {
      await _storage.write(key: _noticeKey, value: value);
    } catch (e, st) {
      AppLogger.error(
        'AlertSeenStore',
        'markEmployeeApprovalNotified',
        e,
        stackTrace: st,
      );
    }
  }

  Future<void> clearEmployeeApprovalNotice() async {
    await load();
    if (_employeeApprovalNoticeKey == null) return;
    _employeeApprovalNoticeKey = null;
    try {
      await _storage.delete(key: _noticeKey);
    } catch (e, st) {
      AppLogger.error(
        'AlertSeenStore',
        'clearEmployeeApprovalNotice',
        e,
        stackTrace: st,
      );
    }
  }

  Future<void> setLastEmployeeStatus(String? status) async {
    await load();
    if (_lastEmployeeStatus == status) return;
    _lastEmployeeStatus = status;
    try {
      if (status == null) {
        await _storage.delete(key: _statusKey);
      } else {
        await _storage.write(key: _statusKey, value: status);
      }
    } catch (e, st) {
      AppLogger.error(
        'AlertSeenStore',
        'setLastEmployeeStatus',
        e,
        stackTrace: st,
      );
    }
  }

  Future<void> markMigrated(Iterable<String> historicalKeys) async {
    await load();
    if (_migrated) return;
    _seen = {..._seen, ...historicalKeys.where((k) => k.trim().isNotEmpty)};
    _migrated = true;
    await _writeSet(_seenKey, _seen);
    try {
      await _storage.write(key: _migratedKey, value: '1');
    } catch (e, st) {
      AppLogger.error('AlertSeenStore', 'markMigrated', e, stackTrace: st);
    }
  }

  Future<void> clear() async {
    _seen = {};
    _oneshot = {};
    _lastEmployeeStatus = null;
    _employeeApprovalNoticeKey = null;
    _migrated = false;
    _loaded = true;
    try {
      await _storage.delete(key: _seenKey);
      await _storage.delete(key: _oneshotKey);
      await _storage.delete(key: _statusKey);
      await _storage.delete(key: _noticeKey);
      await _storage.delete(key: _migratedKey);
    } catch (e, st) {
      AppLogger.error('AlertSeenStore', 'clear', e, stackTrace: st);
    }
  }

  Future<void> _writeSet(String key, Set<String> values) async {
    try {
      await _storage.write(key: key, value: jsonEncode(values.toList()));
    } catch (e, st) {
      AppLogger.error('AlertSeenStore', 'write:$key', e, stackTrace: st);
    }
  }
}
