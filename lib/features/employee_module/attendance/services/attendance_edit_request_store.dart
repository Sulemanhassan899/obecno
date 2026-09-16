import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of attendance fix requests so timeline cards can show
/// pending / approved / rejected history after a request is submitted.
class AttendanceEditRequestStore {
  AttendanceEditRequestStore._();
  static final AttendanceEditRequestStore instance =
      AttendanceEditRequestStore._();

  static const _prefsKey = 'attendance_edit_requests_v1';

  final Map<String, List<AttendanceEditRequest>> _cache = {};
  bool _loaded = false;

  String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  String _entryKey(DateTime day, String eventType) =>
      '${_dayKey(day)}|$eventType';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _cache.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is List) {
              _cache[key.toString()] = AttendanceEditRequest.listFromJson(
                value,
              ).toList();
            }
          });
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  @visibleForTesting
  void debugReset() {
    _cache.clear();
    _loaded = false;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _cache.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      ),
    );
    await prefs.setString(_prefsKey, encoded);
  }

  List<AttendanceEditRequest> forEvent({
    required DateTime day,
    required String eventType,
  }) {
    return List.unmodifiable(_cache[_entryKey(day, eventType)] ?? const []);
  }

  List<AttendanceEditRequest> forDay(DateTime day) {
    final prefix = '${_dayKey(day)}|';
    final out = <AttendanceEditRequest>[];
    for (final entry in _cache.entries) {
      if (entry.key.startsWith(prefix)) out.addAll(entry.value);
    }
    return List.unmodifiable(out);
  }

  bool hasPending(DateTime day) =>
      forDay(day).any((request) => request.isPending);

  bool hasPendingAdd(DateTime day) {
    final pending = forDay(day).where((request) => request.isPending).toList();
    if (pending.isEmpty) return false;
    return pending.every((request) => request.isPendingAdd);
  }

  Future<void> addRequest({
    required DateTime day,
    required String eventType,
    required AttendanceEditRequest request,
  }) async {
    await ensureLoaded();
    final key = _entryKey(day, eventType);
    final existing = List<AttendanceEditRequest>.from(_cache[key] ?? const []);
    // Newest first so responses / latest requests render at the top.
    existing.insert(0, request.copyWith(eventType: eventType));
    _cache[key] = existing;
    await _persist();
  }

  Future<void> addMany({
    required DateTime day,
    required List<AttendanceEditRequest> requests,
  }) async {
    await ensureLoaded();
    for (final request in requests) {
      final type = request.eventType;
      if (type == null || type.isEmpty) continue;
      final key = _entryKey(day, type);
      final existing = List<AttendanceEditRequest>.from(
        _cache[key] ?? const [],
      );
      existing.insert(0, request);
      _cache[key] = existing;
    }
    await _persist();
  }

  /// Drops local pending-add rows once the server has real punches.
  Future<void> clearPendingAdd(DateTime day) async {
    await ensureLoaded();
    final prefix = '${_dayKey(day)}|';
    var changed = false;
    for (final key in _cache.keys.toList()) {
      if (!key.startsWith(prefix)) continue;
      final kept = [
        for (final request in _cache[key]!)
          if (!request.isPendingAdd) request,
      ];
      if (kept.length == (_cache[key]?.length ?? 0)) continue;
      changed = true;
      if (kept.isEmpty) {
        _cache.remove(key);
      } else {
        _cache[key] = kept;
      }
    }
    if (changed) await _persist();
  }
}
