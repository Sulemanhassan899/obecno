import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';

/// Persists leave types, requests, and holidays so Leaves screens and
/// sheets still show data when the device is offline.
class LeaveCacheService {
  LeaveCacheService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String userId) => 'leave_module_cache_$userId';

  Future<void> save({
    required String userId,
    required List<LeaveTypeInfo> types,
    required List<LeaveRequest> requests,
    required List<LeaveHoliday> holidays,
    required String quotaResetLabel,
  }) async {
    if (userId.isEmpty) return;
    try {
      final payload = jsonEncode({
        'quota_reset_label': quotaResetLabel,
        'types': [for (final t in types) t.toCacheJson()],
        'requests': [for (final r in requests) r.toCacheJson()],
        'holidays': [for (final h in holidays) h.toCacheJson()],
        'saved_at': DateTime.now().toIso8601String(),
      });
      await _storage.write(key: _key(userId), value: payload);
    } catch (e, st) {
      AppLogger.error('LeaveCacheService', 'save', e, stackTrace: st);
    }
  }

  Future<LeaveCacheSnapshot?> load(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);

      final types = (map['types'] is List)
          ? (map['types'] as List)
                .whereType<Map>()
                .map(
                  (e) =>
                      LeaveTypeInfo.fromCacheJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : <LeaveTypeInfo>[];

      final requests = (map['requests'] is List)
          ? (map['requests'] as List)
                .whereType<Map>()
                .map(
                  (e) =>
                      LeaveRequest.fromCacheJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : <LeaveRequest>[];

      final holidays = (map['holidays'] is List)
          ? (map['holidays'] as List)
                .whereType<Map>()
                .map((e) => LeaveHoliday.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : <LeaveHoliday>[];

      return LeaveCacheSnapshot(
        types: types,
        requests: requests,
        holidays: holidays,
        quotaResetLabel:
            (map['quota_reset_label'] as String?)?.trim().isNotEmpty == true
            ? (map['quota_reset_label'] as String).trim()
            : 'Leaves quota will be reset after the leave year',
      );
    } catch (e, st) {
      AppLogger.error('LeaveCacheService', 'load', e, stackTrace: st);
      return null;
    }
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      await _storage.delete(key: _key(userId));
    } catch (e, st) {
      AppLogger.error('LeaveCacheService', 'clear', e, stackTrace: st);
    }
  }
}

class LeaveCacheSnapshot {
  const LeaveCacheSnapshot({
    required this.types,
    required this.requests,
    required this.holidays,
    required this.quotaResetLabel,
  });

  final List<LeaveTypeInfo> types;
  final List<LeaveRequest> requests;
  final List<LeaveHoliday> holidays;
  final String quotaResetLabel;
}
