enum TimeComparisonResult { match, mismatch }

extension TimeComparisonResultLabel on TimeComparisonResult {
  String get label => this == TimeComparisonResult.match ? 'MATCH' : 'MISMATCH';
}

/// Wall clock + monotonic snapshot captured at login, app-open, or app-close.
class TimeAnchor {
  const TimeAnchor({
    required this.sessionId,
    required this.kind,
    required this.wallClockLocal,
    required this.wallClockUtc,
    required this.timezoneOffset,
    required this.timezoneName,
    required this.monotonicElapsed,
  });

  final String sessionId;
  final String kind; // 'login' | 'app_open' | 'app_close'
  final DateTime wallClockLocal;
  final DateTime wallClockUtc;
  final Duration timezoneOffset;
  final String timezoneName;
  final Duration monotonicElapsed;

  TimeAnchor copyWith({
    String? sessionId,
    String? kind,
    DateTime? wallClockLocal,
    DateTime? wallClockUtc,
    Duration? timezoneOffset,
    String? timezoneName,
    Duration? monotonicElapsed,
  }) {
    return TimeAnchor(
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      wallClockLocal: wallClockLocal ?? this.wallClockLocal,
      wallClockUtc: wallClockUtc ?? this.wallClockUtc,
      timezoneOffset: timezoneOffset ?? this.timezoneOffset,
      timezoneName: timezoneName ?? this.timezoneName,
      monotonicElapsed: monotonicElapsed ?? this.monotonicElapsed,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'kind': kind,
        'wallClockLocal': wallClockLocal.toIso8601String(),
        'wallClockUtc': wallClockUtc.toIso8601String(),
        'timezoneOffsetMinutes': timezoneOffset.inMinutes,
        'timezoneName': timezoneName,
        'monotonicMs': monotonicElapsed.inMilliseconds,
      };

  factory TimeAnchor.fromJson(Map<String, dynamic> json) {
    return TimeAnchor(
      sessionId: json['sessionId'] as String,
      kind: json['kind'] as String,
      wallClockLocal: DateTime.parse(json['wallClockLocal'] as String),
      wallClockUtc: DateTime.parse(json['wallClockUtc'] as String),
      timezoneOffset: Duration(
        minutes: json['timezoneOffsetMinutes'] as int,
      ),
      timezoneName: json['timezoneName'] as String,
      monotonicElapsed: Duration(milliseconds: json['monotonicMs'] as int),
    );
  }

  static TimeAnchor capture({
    required String sessionId,
    required String kind,
    required DateTime wallClock,
    required Duration monotonicElapsed,
  }) {
    final local = wallClock.isUtc ? wallClock.toLocal() : wallClock;
    return TimeAnchor(
      sessionId: sessionId,
      kind: kind,
      wallClockLocal: local,
      wallClockUtc: local.toUtc(),
      timezoneOffset: local.timeZoneOffset,
      timezoneName: local.timeZoneName,
      monotonicElapsed: monotonicElapsed,
    );
  }
}

class ClockChangeDetection {
  const ClockChangeDetection({
    required this.changed,
    required this.difference,
    required this.wallElapsed,
    required this.monotonicElapsed,
  });

  final bool changed;
  final Duration difference;
  final Duration wallElapsed;
  final Duration monotonicElapsed;
}

class TrustedTimeSnapshot {
  const TrustedTimeSnapshot({
    required this.phoneWallClock,
    required this.currentMonotonic,
    required this.loginAnchor,
    required this.latestAppOpen,
    required this.appOpenCount,
    required this.latestAppClose,
    required this.appCloseCount,
    required this.calculatedActualTime,
    required this.actualEventTime,
    required this.comparison,
    required this.clockChange,
    required this.networkOnline,
    required this.rebootDetected,
    required this.sessionActive,
    this.reasonUnavailable,
  });

  final DateTime phoneWallClock;
  final Duration currentMonotonic;
  final TimeAnchor? loginAnchor;
  final TimeAnchor? latestAppOpen;
  final int appOpenCount;
  final TimeAnchor? latestAppClose;
  final int appCloseCount;
  final DateTime? calculatedActualTime;
  final DateTime? actualEventTime;
  final TimeComparisonResult? comparison;
  final ClockChangeDetection clockChange;
  final bool networkOnline;
  final bool rebootDetected;
  final bool sessionActive;
  final String? reasonUnavailable;

  bool get canIssueAuthoritativeTime =>
      sessionActive &&
      !rebootDetected &&
      calculatedActualTime != null &&
      loginAnchor != null;
}

/// Frozen punch timestamp. Phone wall-clock is never [timeSentToServer].
class AuthoritativePunch {
  const AuthoritativePunch({
    required this.timeSentToServer,
    required this.phoneWallClock,
    required this.calculatedActualTime,
    required this.actualEventTime,
    required this.comparison,
    required this.clockChanged,
    required this.clockDifference,
    required this.monotonicElapsed,
    required this.loginAnchor,
    this.appOpenAnchor,
    this.appCloseAnchor,
    required this.networkOnline,
  });

  final DateTime timeSentToServer;
  final DateTime phoneWallClock;
  final DateTime calculatedActualTime;
  final DateTime actualEventTime;
  final TimeComparisonResult comparison;
  final bool clockChanged;
  final Duration clockDifference;
  final Duration monotonicElapsed;
  final TimeAnchor loginAnchor;
  final TimeAnchor? appOpenAnchor;
  final TimeAnchor? appCloseAnchor;
  final bool networkOnline;
}

class RecordTimeResult {
  const RecordTimeResult.ok(this.punch) : error = null;

  const RecordTimeResult.fail(this.error) : punch = null;

  final AuthoritativePunch? punch;
  final String? error;

  bool get isOk => punch != null;
}
