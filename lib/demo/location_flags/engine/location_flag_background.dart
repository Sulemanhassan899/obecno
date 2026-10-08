import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obecno/demo/location_flags/data/location_flag_store.dart';
import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';
import 'package:obecno/demo/location_flags/engine/location_flag_monitor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Native ↔ Dart channel for 5-minute location-flag ticks while the app is
/// closed, locked, or backgrounded.
const kLocationFlagBgChannel = 'com.obecno/location_flag_bg';

const _prefsKey = 'location_flag_bg_config_v1';
const _alarmId = 91001;

/// Last-known GPS older than this is not trusted for a flag write.
const _maxLastKnownAge = Duration(minutes: 10);

/// Persisted so a headless isolate can capture without the UI Isolate.
class LocationFlagBgConfig {
  const LocationFlagBgConfig({
    required this.enabled,
    required this.employeeId,
    required this.offices,
    required this.policy,
    required this.checkedInAtMs,
    required this.phase,
  });

  final bool enabled;
  final String employeeId;
  final List<AssignedOffice> offices;
  final PolicyWindow policy;
  final int? checkedInAtMs;
  final AttendancePhase phase;

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'employeeId': employeeId,
        'offices': offices
            .map(
              (o) => {
                'id': o.id,
                'name': o.name,
                'latitude': o.latitude,
                'longitude': o.longitude,
                'radiusMeters': o.radiusMeters,
              },
            )
            .toList(),
        'checkInMinutes': policy.checkInMinutes,
        'checkOutMinutes': policy.checkOutMinutes,
        'graceMinutes': policy.graceMinutes,
        'checkedInAtMs': checkedInAtMs,
        'phase': phase.name,
      };

  factory LocationFlagBgConfig.fromJson(Map<String, dynamic> json) {
    final officesRaw = json['offices'];
    final offices = <AssignedOffice>[];
    if (officesRaw is List) {
      for (final row in officesRaw) {
        if (row is! Map) continue;
        offices.add(
          AssignedOffice(
            id: '${row['id'] ?? ''}',
            name: '${row['name'] ?? 'Office'}',
            latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
            radiusMeters: (row['radiusMeters'] as num?)?.toDouble() ?? 100,
          ),
        );
      }
    }
    final phaseName = '${json['phase'] ?? AttendancePhase.notCheckedIn.name}';
    final phase = AttendancePhase.values.firstWhere(
      (p) => p.name == phaseName,
      orElse: () => AttendancePhase.notCheckedIn,
    );
    return LocationFlagBgConfig(
      enabled: json['enabled'] == true,
      employeeId: '${json['employeeId'] ?? ''}',
      offices: offices,
      policy: PolicyWindow(
        checkInMinutes: (json['checkInMinutes'] as num?)?.toInt() ?? 9 * 60,
        checkOutMinutes: (json['checkOutMinutes'] as num?)?.toInt() ?? 18 * 60,
        graceMinutes: (json['graceMinutes'] as num?)?.toInt() ?? 5,
      ),
      checkedInAtMs: (json['checkedInAtMs'] as num?)?.toInt(),
      phase: phase,
    );
  }
}

class LocationFlagBackground {
  LocationFlagBackground._();

  static const channel = MethodChannel(kLocationFlagBgChannel);
  static Future<void> Function()? onLiveTick;
  static bool _handlerBound = false;
  static StreamSubscription<Position>? _positionSub;
  static DateTime? _lastStreamSlot;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Foreground isolate: react when native fires a tick while Flutter is alive.
  static void bindLiveHandler(Future<void> Function() onTick) {
    onLiveTick = onTick;
    if (_handlerBound || !isAndroid) return;
    _handlerBound = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'tick') {
        await onLiveTick?.call();
        return true;
      }
      return null;
    });
  }

  static Future<void> saveConfig(LocationFlagBgConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(config.toJson()));
  }

  static Future<LocationFlagBgConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return LocationFlagBgConfig.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Schedules the next 5-minute slot alarm (and persists config).
  /// Also starts a background-capable GPS stream so locked / backgrounded
  /// phones keep writing inside / outside instead of inventing missing.
  ///
  /// Pass [startStream]: false from the headless isolate — that engine exits
  /// immediately after the tick and cannot hold a live stream.
  static Future<void> arm({
    required LocationFlagBgConfig config,
    DateTime? now,
    bool startStream = true,
  }) async {
    await saveConfig(config);
    if (!config.enabled) {
      await stopLiveTracking();
      await cancel();
      return;
    }
    if (startStream) {
      await startLiveTracking();
    }
    if (!isAndroid) {
      // iOS relies on the Dart stream + Always permission (no exact alarms).
      return;
    }
    final clock = now ?? DateTime.now();
    final next = _nextSlotFireAt(clock, config.policy);
    if (next == null) {
      await cancel();
      return;
    }
    try {
      await channel.invokeMethod<void>('schedule', {
        'id': _alarmId,
        'fireAt': next.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  static Future<void> cancel() async {
    if (!isAndroid) return;
    try {
      await channel.invokeMethod<void>('cancel', {'id': _alarmId});
    } catch (_) {}
  }

  /// Keeps GPS warm while the app is backgrounded / screen locked.
  static Future<void> startLiveTracking() async {
    if (kIsWeb) return;
    // Already running — avoid stop/start churn (and Geolocator FG log spam).
    if (_positionSub != null) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _positionSub = Geolocator.getPositionStream(
        locationSettings: _liveStreamSettings(),
      ).listen(
        (position) {
          unawaited(_onStreamPosition(position));
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  static Future<void> stopLiveTracking() async {
    final sub = _positionSub;
    _positionSub = null;
    _lastStreamSlot = null;
    await sub?.cancel();
  }

  static Future<void> _onStreamPosition(Position position) async {
    final now = DateTime.now();
    final slot = slotStart(now);
    if (_lastStreamSlot != null &&
        _lastStreamSlot!.millisecondsSinceEpoch == slot.millisecondsSinceEpoch) {
      return;
    }
    _lastStreamSlot = slot;
    // Prefer the live UI tick handler when the main isolate is following.
    final tick = onLiveTick;
    if (tick != null) {
      await tick();
      return;
    }
    await runCaptureTick();
  }

  /// Headless / live tick: GPS → SQLite. Missing only when location unavailable.
  static Future<void> runCaptureTick() async {
    final config = await loadConfig();
    if (config == null || !config.enabled || config.employeeId.isEmpty) {
      await cancel();
      return;
    }
    if (config.phase == AttendancePhase.checkedOut) {
      await arm(config: config, startStream: false);
      return;
    }

    final now = DateTime.now();
    final store = await SqliteFlagStore.open();
    final monitor = LocationFlagMonitor(
      store: store,
      employeeId: config.employeeId,
      offices: config.offices.isEmpty ? demoOffices() : config.offices,
      policy: config.policy,
      now: now,
    );
    final saved = await store.sessionFor(config.employeeId);
    if (saved != null && saved.date == monitor.today) {
      monitor.restoreSession(saved);
    } else if (config.checkedInAtMs != null) {
      monitor.phase = AttendancePhase.working;
      monitor.checkedInAt =
          DateTime.fromMillisecondsSinceEpoch(config.checkedInAtMs!);
    } else {
      monitor.phase = config.phase;
    }

    final sample = await readLiveSample(now);
    await monitor.captureThroughNow(sample);
    // Save summaries for this day so history survives across dates.
    final flagStart = config.policy.onDay(now, config.policy.visualStartMinutes);
    final flagEnd = config.policy.onDay(now, config.policy.visualEndMinutes);
    final records = await store.flagsFor(
      employeeId: config.employeeId,
      date: monitor.today,
    );
    await store.replaceStatusIntervals(
      employeeId: config.employeeId,
      date: monitor.today,
      intervals: statusIntervals(
        records,
        checkIn: flagStart,
        checkOut: flagEnd,
        now: now,
      ),
    );
    await store.replaceIssueHours(
      employeeId: config.employeeId,
      date: monitor.today,
      hours: missingOutsideHours(
        records,
        checkIn: flagStart,
        checkOut: flagEnd,
        now: now,
      ),
    );
    await monitor.persistSession();

    final nextConfig = LocationFlagBgConfig(
      enabled: true,
      employeeId: config.employeeId,
      offices: config.offices,
      policy: config.policy,
      checkedInAtMs:
          monitor.checkedInAt?.millisecondsSinceEpoch ?? config.checkedInAtMs,
      phase: monitor.phase,
    );
    await arm(config: nextConfig, now: now, startStream: false);
  }

  static DateTime? _nextSlotFireAt(DateTime now, PolicyWindow policy) {
    final start = policy.onDay(now, policy.visualStartMinutes);
    final end = policy.onDay(now, policy.visualEndMinutes);
    var next = slotStart(now).add(const Duration(minutes: kFlagIntervalMinutes));
    if (next.isBefore(start)) next = start;
    if (!next.isBefore(end)) {
      // After today's window — first slot tomorrow.
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      next = policy.onDay(tomorrow, policy.visualStartMinutes);
    }
    // Never schedule in the past.
    if (!next.isAfter(now)) {
      next = now.add(const Duration(seconds: 30));
    }
    return next;
  }
}

LocationSettings _liveStreamSettings() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      // Time-based flags need ticks even when the device is stationary
      // (emulator / desk). A distance filter skipped most 5-minute slots.
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 60),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Location flags',
        notificationText:
            'Obecno is checking your office location in the background.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.other,
      distanceFilter: 0,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
  );
}

LocationSettings _oneShotSettings() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    // No foregroundNotificationConfig — a one-shot fix must not start/stop
    // Geolocator's Android FG service (that floods logcat with
    // "position updates started/stopped").
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
      pauseLocationUpdatesAutomatically: false,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 20),
  );
}

GpsSample? _sampleFromPosition(Position position, DateTime time) {
  // Emulator / mock locations are valid for the demo — rejecting them left
  // 5-minute slots empty ("No check") while the user was clearly in office.
  return GpsSample(
    timestamp: time,
    latitude: position.latitude,
    longitude: position.longitude,
    accuracyMeters: position.accuracy,
  );
}

Future<GpsSample?> _lastKnownSample(DateTime time) async {
  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last == null) return null;
    final age = time.difference(last.timestamp.toLocal());
    if (age.isNegative) {
      // Device clock skew — still accept a fresh last-known.
    } else if (age > _maxLastKnownAge) {
      return null;
    }
    return _sampleFromPosition(last, time);
  } catch (_) {
    return null;
  }
}

Future<GpsSample> readLiveSample(DateTime time) async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return sampleFailed(time, GpsFailure.unavailable);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return sampleFailed(time, GpsFailure.permissionDenied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _oneShotSettings(),
      );
      final sample = _sampleFromPosition(position, time);
      if (sample != null) return sample;
      return sampleFailed(time, GpsFailure.mock);
    } on TimeoutException {
      final fallback = await _lastKnownSample(time);
      if (fallback != null) return fallback;
      return sampleFailed(time, GpsFailure.timeout);
    } catch (_) {
      final fallback = await _lastKnownSample(time);
      if (fallback != null) return fallback;
      return sampleFailed(time, GpsFailure.unavailable);
    }
  } catch (_) {
    final fallback = await _lastKnownSample(time);
    if (fallback != null) return fallback;
    return sampleFailed(time, GpsFailure.unavailable);
  }
}

/// Headless entrypoint started by [LocationFlagBackgroundWorker] when the app
/// process is not running. Prefer calling via [locationFlagBackgroundEntrypoint]
/// from `main.dart` so the native engine can resolve the symbol.
@pragma('vm:entry-point')
void locationFlagBackgroundEntrypoint() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(
    () async {
      await LocationFlagBackground.runCaptureTick();
      try {
        await const MethodChannel(kLocationFlagBgChannel)
            .invokeMethod<void>('done');
      } catch (_) {}
    },
    (_, __) {},
  );
}
