import 'package:system_clock/system_clock.dart';

/// Elapsed time that does not jump when the user changes the phone date/time.
/// Production maps to Android `elapsedRealtime()` via `system_clock`.
/// Resets across device reboot. Injectable so tests can fake progression.
abstract class MonotonicClock {
  Duration elapsedRealtime();
}

class SystemMonotonicClock implements MonotonicClock {
  const SystemMonotonicClock();

  @override
  Duration elapsedRealtime() => SystemClock.elapsedRealtime();
}

/// Guards punch time against a wall-tracking native clock without dropping
/// a real boot clock.
///
/// `system_clock`'s non-IO stub uses `DateTime.now()` as "elapsed realtime".
/// Those epoch-sized readings follow the phone date/time, so this wrapper
/// freezes them at construction and only adds [Stopwatch] time after that.
///
/// On Android/iOS the native value is time since boot (hours/days, never
/// decades). That clock already includes sleep and must be used as-is —
/// wrapping it in [Stopwatch] made check-out lag the header clock after
/// the phone slept or the app was backgrounded.
class AnchoredMonotonicClock implements MonotonicClock {
  AnchoredMonotonicClock(this._native)
      : _nativeAtStart = _native.elapsedRealtime();

  final MonotonicClock _native;
  final Duration _nativeAtStart;
  final Stopwatch _watch = Stopwatch()..start();

  /// Epoch-based stub readings are ~decades. Real uptime is hours to months.
  static bool looksLikeWallClock(Duration elapsed) => elapsed.inDays > 3650;

  @override
  Duration elapsedRealtime() {
    final nativeNow = _native.elapsedRealtime();
    if (!looksLikeWallClock(_nativeAtStart) && !looksLikeWallClock(nativeNow)) {
      return nativeNow;
    }
    return _nativeAtStart + _watch.elapsed;
  }
}

/// Test monotonic clock. [advance] for real elapsed time;
/// [simulateReboot] resets like `elapsedRealtime()` after a reboot.
class FakeMonotonicClock implements MonotonicClock {
  FakeMonotonicClock([Duration elapsed = Duration.zero]) : _elapsed = elapsed;

  Duration _elapsed;

  @override
  Duration elapsedRealtime() => _elapsed;

  void advance(Duration duration) {
    _elapsed += duration;
  }

  void setElapsed(Duration elapsed) {
    _elapsed = elapsed;
  }

  void simulateReboot({Duration elapsed = Duration.zero}) {
    _elapsed = elapsed;
  }
}

/// Device wall-clock (`DateTime.now()`). Display only — never an attendance
/// timestamp. Injectable so tests can move phone time independently.
abstract class WallClock {
  DateTime now();
}

class SystemWallClock implements WallClock {
  const SystemWallClock();

  @override
  DateTime now() => DateTime.now();
}

class FakeWallClock implements WallClock {
  FakeWallClock(DateTime now) : _now = now;

  DateTime _now;

  @override
  DateTime now() => _now;

  void setNow(DateTime value) {
    _now = value;
  }

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
