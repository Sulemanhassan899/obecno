import 'package:obecno/features/clock/domain/trusted_time_models.dart';

/// Centralized actual-time calculation.
///
/// Formula:
///   elapsed = currentMonotonic - loginMonotonic
///   calculatedActualTime = loginWallClock + elapsed
///
/// The device wall clock is NEVER used as the attendance timestamp.
/// It is only compared against monotonic elapsed time to detect manipulation.
///
/// A client-side monotonic clock can protect against device-clock changes
/// AFTER the initial time anchor, but it cannot prove that the initial
/// device wall-clock (the login time) was truthful.
///
/// Preferred production architecture:
///   Server Trusted Time
///     → Initial Session Time Anchor
///     → Monotonic Clock
///     → Calculated Actual Time
///     → Attendance Event
///     → Local Storage
///     → Offline Queue
///     → Server Validation
///
/// If the API later exposes a trusted server timestamp at login, store that
/// as [TimeAnchor.wallClockLocal] instead of `DateTime.now()`.
class TrustedTimeCalculator {
  const TrustedTimeCalculator({
    this.clockSkewThreshold = const Duration(minutes: 2),
  });

  /// Wall-vs-monotonic mismatch larger than this is treated as a clock change.
  final Duration clockSkewThreshold;

  TrustedTimeSnapshot calculate({
    required DateTime phoneWallClock,
    required Duration currentMonotonic,
    required TimeAnchor? loginAnchor,
    required TimeAnchor? latestAppOpen,
    required int appOpenCount,
    required TimeAnchor? latestAppClose,
    required int appCloseCount,
    required bool networkOnline,
    required bool sessionActive,
    DateTime? trustedActualTime,
  }) {
    TrustedTimeSnapshot unavailable({
      required bool reboot,
      required bool active,
      required String reason,
    }) {
      return TrustedTimeSnapshot(
        phoneWallClock: phoneWallClock,
        currentMonotonic: currentMonotonic,
        loginAnchor: loginAnchor,
        latestAppOpen: latestAppOpen,
        appOpenCount: appOpenCount,
        latestAppClose: latestAppClose,
        appCloseCount: appCloseCount,
        calculatedActualTime: null,
        actualEventTime: null,
        comparison: null,
        clockChange: const ClockChangeDetection(
          changed: false,
          difference: Duration.zero,
          wallElapsed: Duration.zero,
          monotonicElapsed: Duration.zero,
        ),
        networkOnline: networkOnline,
        rebootDetected: reboot,
        sessionActive: active,
        reasonUnavailable: reason,
      );
    }

    if (!sessionActive || loginAnchor == null) {
      return unavailable(
        reboot: false,
        active: false,
        reason: 'No active employee session. Log in first.',
      );
    }

    final rebootDetected = currentMonotonic < loginAnchor.monotonicElapsed ||
        (latestAppOpen != null &&
            currentMonotonic < latestAppOpen.monotonicElapsed);

    if (rebootDetected) {
      return unavailable(
        reboot: true,
        active: sessionActive,
        reason:
            'Device reboot detected. Monotonic clock reset — '
            'refusing to invent an authoritative timestamp. '
            'Re-login (or re-anchor from server time in production).',
      );
    }

    final elapsed = currentMonotonic - loginAnchor.monotonicElapsed;
    final calculatedActualTime = loginAnchor.wallClockLocal.add(elapsed);
    final actualEventTime = trustedActualTime ?? calculatedActualTime;

    final wallElapsed = phoneWallClock.difference(loginAnchor.wallClockLocal);
    final difference = wallElapsed - elapsed;
    final changed = difference.abs() > clockSkewThreshold;

    final comparisonDelta =
        actualEventTime.difference(calculatedActualTime).abs();
    final comparison = comparisonDelta <= clockSkewThreshold
        ? TimeComparisonResult.match
        : TimeComparisonResult.mismatch;

    return TrustedTimeSnapshot(
      phoneWallClock: phoneWallClock,
      currentMonotonic: currentMonotonic,
      loginAnchor: loginAnchor,
      latestAppOpen: latestAppOpen,
      appOpenCount: appOpenCount,
      latestAppClose: latestAppClose,
      appCloseCount: appCloseCount,
      calculatedActualTime: calculatedActualTime,
      actualEventTime: actualEventTime,
      comparison: comparison,
      clockChange: ClockChangeDetection(
        changed: changed,
        difference: difference,
        wallElapsed: wallElapsed,
        monotonicElapsed: elapsed,
      ),
      networkOnline: networkOnline,
      rebootDetected: false,
      sessionActive: true,
    );
  }
}
