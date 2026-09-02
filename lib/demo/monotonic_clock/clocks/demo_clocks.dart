import 'package:system_clock/system_clock.dart';

/// Source of elapsed time that does not jump when the user changes the
/// phone date/time. Production uses Android `elapsedRealtime()` (via
/// `system_clock`). Injectable so tests can fake progression and reboot.
abstract class MonotonicClock {
  Duration elapsedRealtime();
}

/// Production monotonic clock. Maps to `SystemClock.elapsedRealtime()`,
/// which is independent of the wall clock. Resets across device reboot.
class SystemMonotonicClock implements MonotonicClock {
  const SystemMonotonicClock();

  @override
  Duration elapsedRealtime() => SystemClock.elapsedRealtime();
}

/// Test / simulated monotonic clock. Call [advance] for real elapsed time
/// and [simulateReboot] to reset like `elapsedRealtime()` after a reboot.
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

  /// `elapsedRealtime()` does not continue across reboot.
  void simulateReboot({Duration elapsed = Duration.zero}) {
    _elapsed = elapsed;
  }
}

/// Source of device wall-clock time (`DateTime.now()`). Injectable so tests
/// can move the phone clock forward or backward without touching monotonic.
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

/// Wraps any [MonotonicClock] so the demo can jump elapsed time in LIVE
/// and SIMULATED mode without changing the emulator clock.
class AdjustableMonotonicClock implements MonotonicClock {
  AdjustableMonotonicClock(this._inner);

  MonotonicClock _inner;
  Duration adjustment = Duration.zero;

  void setInner(MonotonicClock inner, {bool resetAdjustment = true}) {
    _inner = inner;
    if (resetAdjustment) adjustment = Duration.zero;
  }

  @override
  Duration elapsedRealtime() => _inner.elapsedRealtime() + adjustment;

  void advance(Duration duration) {
    adjustment += duration;
  }

  /// Makes current elapsed appear small, like `elapsedRealtime()` after reboot.
  void simulateReboot({Duration elapsed = const Duration(seconds: 12)}) {
    adjustment = elapsed - _inner.elapsedRealtime();
  }
}

/// Wraps any [WallClock] so the demo can move phone time independently
/// of monotonic elapsed time.
class AdjustableWallClock implements WallClock {
  AdjustableWallClock(this._inner);

  WallClock _inner;
  Duration adjustment = Duration.zero;

  void setInner(WallClock inner, {bool resetAdjustment = true}) {
    _inner = inner;
    if (resetAdjustment) adjustment = Duration.zero;
  }

  DateTime rawNow() => _inner.now();

  @override
  DateTime now() => _inner.now().add(adjustment);

  void advance(Duration duration) {
    adjustment += duration;
  }

  void setNow(DateTime value) {
    adjustment = value.difference(_inner.now());
  }
}
