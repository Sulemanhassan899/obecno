import 'dart:convert';

import 'package:obecno/demo/monotonic_clock/domain/demo_time_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class DemoTimeStore {
  Future<void> saveSessionId(String? sessionId);
  Future<String?> loadSessionId();

  Future<void> saveLoginAnchor(TimeAnchor? anchor);
  Future<TimeAnchor?> loadLoginAnchor();

  Future<void> saveAppOpens(List<TimeAnchor> opens);
  Future<List<TimeAnchor>> loadAppOpens();

  Future<void> saveAppCloses(List<TimeAnchor> closes);
  Future<List<TimeAnchor>> loadAppCloses();

  Future<void> saveEvents(List<TrustedAttendanceEvent> events);
  Future<List<TrustedAttendanceEvent>> loadEvents();

  Future<void> savePendingQueue(List<TrustedAttendanceEvent> events);
  Future<List<TrustedAttendanceEvent>> loadPendingQueue();

  Future<void> saveLastObservedMonotonic(Duration? elapsed);
  Future<Duration?> loadLastObservedMonotonic();

  Future<void> saveSessionActive(bool active);
  Future<bool> loadSessionActive();

  Future<void> clearAll();
}

class InMemoryDemoTimeStore implements DemoTimeStore {
  String? _sessionId;
  TimeAnchor? _login;
  List<TimeAnchor> _appOpens = const [];
  List<TimeAnchor> _appCloses = const [];
  List<TrustedAttendanceEvent> _events = const [];
  List<TrustedAttendanceEvent> _pending = const [];
  Duration? _lastMonotonic;
  bool _sessionActive = false;

  @override
  Future<void> saveSessionId(String? sessionId) async => _sessionId = sessionId;

  @override
  Future<String?> loadSessionId() async => _sessionId;

  @override
  Future<void> saveLoginAnchor(TimeAnchor? anchor) async => _login = anchor;

  @override
  Future<TimeAnchor?> loadLoginAnchor() async => _login;

  @override
  Future<void> saveAppOpens(List<TimeAnchor> opens) async =>
      _appOpens = List.of(opens);

  @override
  Future<List<TimeAnchor>> loadAppOpens() async => List.of(_appOpens);

  @override
  Future<void> saveAppCloses(List<TimeAnchor> closes) async =>
      _appCloses = List.of(closes);

  @override
  Future<List<TimeAnchor>> loadAppCloses() async => List.of(_appCloses);

  @override
  Future<void> saveEvents(List<TrustedAttendanceEvent> events) async =>
      _events = List.of(events);

  @override
  Future<List<TrustedAttendanceEvent>> loadEvents() async => List.of(_events);

  @override
  Future<void> savePendingQueue(List<TrustedAttendanceEvent> events) async =>
      _pending = List.of(events);

  @override
  Future<List<TrustedAttendanceEvent>> loadPendingQueue() async =>
      List.of(_pending);

  @override
  Future<void> saveLastObservedMonotonic(Duration? elapsed) async =>
      _lastMonotonic = elapsed;

  @override
  Future<Duration?> loadLastObservedMonotonic() async => _lastMonotonic;

  @override
  Future<void> saveSessionActive(bool active) async => _sessionActive = active;

  @override
  Future<bool> loadSessionActive() async => _sessionActive;

  @override
  Future<void> clearAll() async {
    _sessionId = null;
    _login = null;
    _appOpens = const [];
    _appCloses = const [];
    _events = const [];
    _pending = const [];
    _lastMonotonic = null;
    _sessionActive = false;
  }
}

class PrefsDemoTimeStore implements DemoTimeStore {
  PrefsDemoTimeStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kSessionId = 'demo_monotonic_session_id';
  static const _kLogin = 'demo_monotonic_login_anchor';
  static const _kAppOpens = 'demo_monotonic_app_opens';
  static const _kAppCloses = 'demo_monotonic_app_closes';
  static const _kEvents = 'demo_monotonic_events';
  static const _kPending = 'demo_monotonic_pending_queue';
  static const _kLastMono = 'demo_monotonic_last_observed';
  static const _kActive = 'demo_monotonic_session_active';

  @override
  Future<void> saveSessionId(String? sessionId) async {
    if (sessionId == null) {
      await _prefs.remove(_kSessionId);
    } else {
      await _prefs.setString(_kSessionId, sessionId);
    }
  }

  @override
  Future<String?> loadSessionId() async => _prefs.getString(_kSessionId);

  @override
  Future<void> saveLoginAnchor(TimeAnchor? anchor) async {
    if (anchor == null) {
      await _prefs.remove(_kLogin);
    } else {
      await _prefs.setString(_kLogin, jsonEncode(anchor.toJson()));
    }
  }

  @override
  Future<TimeAnchor?> loadLoginAnchor() async {
    final raw = _prefs.getString(_kLogin);
    if (raw == null) return null;
    return TimeAnchor.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveAppOpens(List<TimeAnchor> opens) async {
    await _prefs.setString(
      _kAppOpens,
      jsonEncode(opens.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<TimeAnchor>> loadAppOpens() async {
    final raw = _prefs.getString(_kAppOpens);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TimeAnchor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveAppCloses(List<TimeAnchor> closes) async {
    await _prefs.setString(
      _kAppCloses,
      jsonEncode(closes.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<TimeAnchor>> loadAppCloses() async {
    final raw = _prefs.getString(_kAppCloses);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TimeAnchor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveEvents(List<TrustedAttendanceEvent> events) async {
    await _prefs.setString(
      _kEvents,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<TrustedAttendanceEvent>> loadEvents() async {
    final raw = _prefs.getString(_kEvents);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TrustedAttendanceEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> savePendingQueue(List<TrustedAttendanceEvent> events) async {
    await _prefs.setString(
      _kPending,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<TrustedAttendanceEvent>> loadPendingQueue() async {
    final raw = _prefs.getString(_kPending);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TrustedAttendanceEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveLastObservedMonotonic(Duration? elapsed) async {
    if (elapsed == null) {
      await _prefs.remove(_kLastMono);
    } else {
      await _prefs.setInt(_kLastMono, elapsed.inMilliseconds);
    }
  }

  @override
  Future<Duration?> loadLastObservedMonotonic() async {
    final ms = _prefs.getInt(_kLastMono);
    if (ms == null) return null;
    return Duration(milliseconds: ms);
  }

  @override
  Future<void> saveSessionActive(bool active) async {
    await _prefs.setBool(_kActive, active);
  }

  @override
  Future<bool> loadSessionActive() async => _prefs.getBool(_kActive) ?? false;

  @override
  Future<void> clearAll() async {
    await _prefs.remove(_kSessionId);
    await _prefs.remove(_kLogin);
    await _prefs.remove(_kAppOpens);
    await _prefs.remove(_kAppCloses);
    await _prefs.remove(_kEvents);
    await _prefs.remove(_kPending);
    await _prefs.remove(_kLastMono);
    await _prefs.remove(_kActive);
  }
}
