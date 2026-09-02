enum DemoAttendanceEventType {
  checkIn,
  breakIn,
  breakOut,
  checkOut,
}

extension DemoAttendanceEventTypeLabel on DemoAttendanceEventType {
  String get label {
    switch (this) {
      case DemoAttendanceEventType.checkIn:
        return 'CHECK IN';
      case DemoAttendanceEventType.breakIn:
        return 'BREAK IN';
      case DemoAttendanceEventType.breakOut:
        return 'BREAK OUT';
      case DemoAttendanceEventType.checkOut:
        return 'CHECK OUT';
    }
  }

  String get logName {
    switch (this) {
      case DemoAttendanceEventType.checkIn:
        return 'CHECK_IN';
      case DemoAttendanceEventType.breakIn:
        return 'BREAK_IN';
      case DemoAttendanceEventType.breakOut:
        return 'BREAK_OUT';
      case DemoAttendanceEventType.checkOut:
        return 'CHECK_OUT';
    }
  }
}

enum TimeComparisonResult { match, mismatch }

extension TimeComparisonResultLabel on TimeComparisonResult {
  String get label => this == TimeComparisonResult.match ? 'MATCH' : 'MISMATCH';
}

/// Wall clock + monotonic snapshot captured at login or app-open.
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

class TrustedAttendanceEvent {
  const TrustedAttendanceEvent({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.phoneWallClock,
    required this.monotonicElapsed,
    required this.loginAnchor,
    required this.appOpenAnchor,
    this.appCloseAnchor,
    required this.calculatedActualTime,
    required this.actualEventTime,
    required this.comparison,
    required this.clockChanged,
    required this.clockDifference,
    required this.networkOnline,
    required this.authoritativeTime,
    required this.timeSentToServer,
    required this.synced,
    required this.createdAtMonotonic,
  });

  final String id;
  final String sessionId;
  final DemoAttendanceEventType type;
  final DateTime phoneWallClock;
  final Duration monotonicElapsed;
  final TimeAnchor loginAnchor;
  final TimeAnchor? appOpenAnchor;
  final TimeAnchor? appCloseAnchor;
  final DateTime calculatedActualTime;
  final DateTime actualEventTime;
  final TimeComparisonResult comparison;
  final bool clockChanged;
  final Duration clockDifference;
  final bool networkOnline;
  final DateTime authoritativeTime;
  final DateTime timeSentToServer;
  final bool synced;
  final Duration createdAtMonotonic;

  TrustedAttendanceEvent copyWith({bool? synced}) {
    return TrustedAttendanceEvent(
      id: id,
      sessionId: sessionId,
      type: type,
      phoneWallClock: phoneWallClock,
      monotonicElapsed: monotonicElapsed,
      loginAnchor: loginAnchor,
      appOpenAnchor: appOpenAnchor,
      appCloseAnchor: appCloseAnchor,
      calculatedActualTime: calculatedActualTime,
      actualEventTime: actualEventTime,
      comparison: comparison,
      clockChanged: clockChanged,
      clockDifference: clockDifference,
      networkOnline: networkOnline,
      authoritativeTime: authoritativeTime,
      timeSentToServer: timeSentToServer,
      synced: synced ?? this.synced,
      createdAtMonotonic: createdAtMonotonic,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'type': type.name,
        'phoneWallClock': phoneWallClock.toIso8601String(),
        'monotonicMs': monotonicElapsed.inMilliseconds,
        'loginAnchor': loginAnchor.toJson(),
        'appOpenAnchor': appOpenAnchor?.toJson(),
        'appCloseAnchor': appCloseAnchor?.toJson(),
        'calculatedActualTime': calculatedActualTime.toIso8601String(),
        'actualEventTime': actualEventTime.toIso8601String(),
        'comparison': comparison.name,
        'clockChanged': clockChanged,
        'clockDifferenceMs': clockDifference.inMilliseconds,
        'networkOnline': networkOnline,
        'authoritativeTime': authoritativeTime.toIso8601String(),
        'timeSentToServer': timeSentToServer.toIso8601String(),
        'synced': synced,
        'createdAtMonotonicMs': createdAtMonotonic.inMilliseconds,
      };

  factory TrustedAttendanceEvent.fromJson(Map<String, dynamic> json) {
    final calculated = DateTime.parse(json['calculatedActualTime'] as String);
    final actual = json['actualEventTime'] == null
        ? calculated
        : DateTime.parse(json['actualEventTime'] as String);
    return TrustedAttendanceEvent(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      type: DemoAttendanceEventType.values.byName(json['type'] as String),
      phoneWallClock: DateTime.parse(json['phoneWallClock'] as String),
      monotonicElapsed: Duration(milliseconds: json['monotonicMs'] as int),
      loginAnchor: TimeAnchor.fromJson(
        json['loginAnchor'] as Map<String, dynamic>,
      ),
      appOpenAnchor: json['appOpenAnchor'] == null
          ? null
          : TimeAnchor.fromJson(json['appOpenAnchor'] as Map<String, dynamic>),
      appCloseAnchor: json['appCloseAnchor'] == null
          ? null
          : TimeAnchor.fromJson(json['appCloseAnchor'] as Map<String, dynamic>),
      calculatedActualTime: calculated,
      actualEventTime: actual,
      comparison: json['comparison'] == 'mismatch'
          ? TimeComparisonResult.mismatch
          : TimeComparisonResult.match,
      clockChanged: json['clockChanged'] as bool,
      clockDifference: Duration(milliseconds: json['clockDifferenceMs'] as int),
      networkOnline: json['networkOnline'] as bool,
      authoritativeTime: DateTime.parse(json['authoritativeTime'] as String),
      timeSentToServer: DateTime.parse(json['timeSentToServer'] as String),
      synced: json['synced'] as bool,
      createdAtMonotonic: Duration(
        milliseconds: json['createdAtMonotonicMs'] as int,
      ),
    );
  }
}

class RecordEventResult {
  const RecordEventResult.ok(this.event) : error = null;

  const RecordEventResult.fail(this.error) : event = null;

  final TrustedAttendanceEvent? event;
  final String? error;

  bool get isOk => event != null;
}

class SyncResult {
  const SyncResult({
    required this.synced,
    required this.preservedTimestamps,
  });

  final List<TrustedAttendanceEvent> synced;

  /// Original [TrustedAttendanceEvent.timeSentToServer] values, in order.
  final List<DateTime> preservedTimestamps;
}
