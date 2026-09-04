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

/// Process-local elapsed time that cannot follow the phone wall clock.
///
/// `system_clock`'s non-IO stub uses `DateTime.now()` as "elapsed realtime".
/// This wrapper freezes the native reading at construction and only adds
/// [Stopwatch] time after that — [Stopwatch] is monotonic for the life of
/// the isolate, so changing the emulator date/time cannot move punch time.
class AnchoredMonotonicClock implements MonotonicClock {
  AnchoredMonotonicClock(this._native)
      : _nativeAtStart = _native.elapsedRealtime();

  final MonotonicClock _native;
  final Duration _nativeAtStart;
  final Stopwatch _watch = Stopwatch()..start();

  @override
  Duration elapsedRealtime() => _nativeAtStart + _watch.elapsed;
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
