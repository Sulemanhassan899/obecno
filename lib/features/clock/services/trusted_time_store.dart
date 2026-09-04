import 'dart:convert';

import 'package:obecno/features/clock/domain/trusted_time_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TrustedTimeStore {
  Future<void> saveSessionId(String? sessionId);
  Future<String?> loadSessionId();

  Future<void> saveLoginAnchor(TimeAnchor? anchor);
  Future<TimeAnchor?> loadLoginAnchor();

  Future<void> saveAppOpens(List<TimeAnchor> opens);
  Future<List<TimeAnchor>> loadAppOpens();

  Future<void> saveAppCloses(List<TimeAnchor> closes);
  Future<List<TimeAnchor>> loadAppCloses();

  Future<void> saveLastObservedMonotonic(Duration? elapsed);
  Future<Duration?> loadLastObservedMonotonic();

  Future<void> saveSessionActive(bool active);
  Future<bool> loadSessionActive();

  Future<void> clearAll();
}

class InMemoryTrustedTimeStore implements TrustedTimeStore {
  String? _sessionId;
  TimeAnchor? _login;
  List<TimeAnchor> _appOpens = const [];
  List<TimeAnchor> _appCloses = const [];
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
    _lastMonotonic = null;
    _sessionActive = false;
  }
}

class PrefsTrustedTimeStore implements TrustedTimeStore {
  PrefsTrustedTimeStore(this._prefs, {required String userId})
      : _userId = userId;

  final SharedPreferences _prefs;
  String _userId;

  String get userId => _userId;

  void setUserId(String userId) {
    _userId = userId;
  }

  String get _kSessionId => 'clock_trusted_session_id_$_userId';
  String get _kLogin => 'clock_trusted_login_anchor_$_userId';
  String get _kAppOpens => 'clock_trusted_app_opens_$_userId';
  String get _kAppCloses => 'clock_trusted_app_closes_$_userId';
  String get _kLastMono => 'clock_trusted_last_observed_$_userId';
  String get _kActive => 'clock_trusted_session_active_$_userId';

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
    await _prefs.remove(_kLastMono);
    await _prefs.remove(_kActive);
  }
}
