import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/demo/location_flags/data/location_flag_store.dart';
import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';
import 'package:obecno/demo/location_flags/engine/location_flag_monitor.dart';
import 'package:obecno/demo/location_flags/engine/smart_attendance_engine.dart';

void main() {
  final day = DateTime(2026, 9, 21, 9);

  Future<({LocationFlagMonitor engine, MemoryFlagStore store})> start() async {
    final store = MemoryFlagStore();
    final engine = LocationFlagMonitor(
      store: store,
      employeeId: 'employee_a',
      offices: demoOffices(),
      policy: const PolicyWindow(
        checkInMinutes: 9 * 60,
        checkOutMinutes: 18 * 60,
      ),
      now: day,
    );
    return (engine: engine, store: store);
  }

  test('radius boundary is inclusive', () {
    expect(withinRadius(100, 100), isTrue);
    expect(withinRadius(100.1, 100), isFalse);
  });

  test('twelve flags and a new cycle on the next hour', () {
    final hour = DateTime(2026, 9, 21, 9);
    final slots = slotsInHour(hour);
    expect(slots.length, 12);
    expect(flagNumberFor(slots.first), 1);
    expect(flagNumberFor(slots.last), 12);
    expect(slots.last.minute, 55);
    expect(
      cycleIdFor(slots.first),
      isNot(cycleIdFor(DateTime(2026, 9, 21, 10))),
    );
    expect(flagNumberFor(DateTime(2026, 9, 21, 10)), 1);
  });

  test('inside one of many offices is true and stores the match', () {
    final offices = demoOffices();
    final match = matchOffices(sampleInside(offices[2], day), offices);
    expect(match.value, FlagValue.inside);
    expect(match.matched!.id, 'office_C');
  });

  test('outside every office is false', () {
    final match = matchOffices(sampleOutside(day), demoOffices());
    expect(match.value, FlagValue.outside);
    expect(match.matched, isNull);
  });

  test('gps failure without a fix is unavailable; coarse fix still classifies', () {
    final offices = demoOffices();
    for (final failure in [
      GpsFailure.unavailable,
      GpsFailure.permissionDenied,
      GpsFailure.timeout,
      GpsFailure.mock,
      GpsFailure.poorAccuracy,
    ]) {
      expect(
        matchOffices(sampleFailed(day, failure), offices).value,
        FlagValue.unavailable,
      );
    }
    // Coarse accuracy with real coordinates is still location-available.
    expect(
      matchOffices(
        GpsSample(
          timestamp: day,
          latitude: offices.first.latitude,
          longitude: offices.first.longitude,
          accuracyMeters: 180,
        ),
        offices,
      ).value,
      FlagValue.inside,
    );
  });

  test('inside and not checked in', () async {
    final harness = await start();
    final record = await harness.engine.capture(
      sampleInside(harness.engine.offices[0], day),
    );
    expect(record!.value, FlagValue.inside);
    expect(record.violation, isFalse);
    final alerts = await harness.store.alertsFor('employee_a');
    expect(alerts.single.message, contains('Please check in'));
    expect(alerts.single.message, contains('Office A'));
  });

  test('outside and not checked in has no checkout warning', () async {
    final harness = await start();
    final record = await harness.engine.capture(sampleOutside(day));
    expect(record!.value, FlagValue.outside);
    expect(record.violation, isFalse);
    expect(await harness.store.alertsFor('employee_a'), isEmpty);
  });

  test('inside and checked in stores the office and does not warn', () async {
    final harness = await start();
    harness.engine.checkIn();
    final record = await harness.engine.capture(
      sampleInside(harness.engine.offices[0], day),
    );
    expect(record!.value, FlagValue.inside);
    expect(record.matchedLocationName, 'Office A');
    expect(record.violation, isFalse);
    expect(await harness.store.alertsFor('employee_a'), isEmpty);
  });

  test('outside and checked in is a location issue', () async {
    final harness = await start();
    harness.engine.checkIn();
    final record = await harness.engine.capture(sampleOutside(day));
    expect(record!.value, FlagValue.outside);
    expect(record.violation, isTrue);
    expect(record.syncState, SyncState.pending);
    final alerts = await harness.store.alertsFor('employee_a');
    expect(alerts.single.message, contains('Please check out'));
  });

  test('break is yellow and not a working violation', () async {
    final harness = await start();
    harness.engine.checkIn();
    await harness.engine.capture(sampleInside(harness.engine.offices[0], day));
    harness.engine.setClock(day.add(const Duration(minutes: 5)));
    harness.engine.breakIn();
    final record = await harness.engine.capture(
      sampleOutside(harness.engine.now),
    );
    expect(record!.kind, SlotKind.onBreak);
    expect(record.violation, isFalse);
    final rows = await harness.store.flagsFor(
      employeeId: 'employee_a',
      date: dateKey(day),
    );
    expect(rows, hasLength(2));
  });

  test('break out resumes working evaluation', () async {
    final harness = await start();
    harness.engine.checkIn();
    harness.engine.breakIn();
    harness.engine.breakOut();
    final record = await harness.engine.capture(sampleOutside(day));
    expect(record!.phase, AttendancePhase.working);
    expect(record.violation, isTrue);
  });

  test('check out stops later flags', () async {
    final harness = await start();
    harness.engine.checkIn();
    await harness.engine.capture(sampleInside(harness.engine.offices[0], day));
    harness.engine.checkOut();
    harness.engine.setClock(day.add(const Duration(minutes: 5)));
    expect(
      await harness.engine.capture(sampleOutside(harness.engine.now)),
      isNull,
    );
    final rows = await harness.store.flagsFor(
      employeeId: 'employee_a',
      date: dateKey(day),
    );
    expect(rows, hasLength(1));
  });

  test('gps unavailable writes missing; unchecked slots stay empty', () async {
    final harness = await start();
    harness.engine.checkIn();
    await harness.engine.capture(sampleInside(harness.engine.offices[0], day));
    harness.engine.setClock(day.add(const Duration(minutes: 5)));
    await harness.engine.capture(
      sampleFailed(harness.engine.now, GpsFailure.unavailable),
    );
    harness.engine.setClock(day.add(const Duration(minutes: 10)));
    await harness.engine.markMissedSlots();
    final rows = await harness.store.flagsFor(
      employeeId: 'employee_a',
      date: dateKey(day),
    );
    expect(rows, hasLength(2));
    final missed = rows.singleWhere((row) => row.scheduledAt.minute == 5);
    expect(missed.kind, SlotKind.missing);
    expect(missed.value, FlagValue.unavailable);
    expect(rows.any((row) => row.scheduledAt.minute == 10), isFalse);
  });

  test('gps capture replaces a missing placeholder for the same slot', () async {
    final harness = await start();
    harness.engine.checkIn();
    await harness.engine.capture(
      sampleFailed(day, GpsFailure.unavailable),
    );
    final before = await harness.store.flagsFor(
      employeeId: 'employee_a',
      date: dateKey(day),
    );
    expect(before.any((row) => row.kind == SlotKind.missing), isTrue);

    harness.engine.setClock(day);
    final replaced = await harness.engine.capture(
      sampleInside(harness.engine.offices[0], day),
    );
    expect(replaced, isNotNull);
    expect(replaced!.kind, SlotKind.inside);
    expect(replaced.value, FlagValue.inside);

    final rows = await harness.store.flagsFor(
      employeeId: 'employee_a',
      date: dateKey(day),
    );
    final atDay = rows.singleWhere(
      (row) => row.scheduledAt.millisecondsSinceEpoch == day.millisecondsSinceEpoch,
    );
    expect(atDay.kind, SlotKind.inside);
  });

  test('empty store does not invent a full day of missing flags', () async {
    final harness = await start();
    harness.engine.setClock(DateTime(2026, 9, 21, 17, 30));
    await harness.engine.persistResolvedGaps();
    final rows = await harness.store.flagsFor(
      employeeId: 'employee_a',
      date: dateKey(day),
    );
    expect(rows, isEmpty);
  });

  test('offline pending sync retries without a second slot', () async {
    final harness = await start();
    harness.engine.checkIn();
    harness.engine.offline = true;
    final first = await harness.engine.capture(sampleOutside(day));
    expect(first!.syncState, SyncState.pending);
    final failed = await harness.engine.syncPending();
    expect(failed.single.syncState, SyncState.failed);
    harness.engine.offline = false;
    final synced = await harness.engine.syncPending();
    expect(synced.single.syncState, SyncState.synced);
    final again = await harness.engine.capture(sampleOutside(day));
    expect(again!.eventId, first.eventId);
    final rows = await harness.store.flagsFor(
      employeeId: 'employee_a',
      date: dateKey(day),
    );
    expect(rows, hasLength(1));
  });

  test('employee switch does not write the previous employee', () async {
    final harness = await start();
    harness.engine.checkIn();
    await harness.engine.capture(sampleInside(harness.engine.offices[0], day));
    harness.engine.adoptEmployee('employee_b');
    harness.engine.checkIn();
    await harness.engine.capture(sampleOutside(day));
    final a = await harness.store.flagsFor(
      employeeId: 'employee_a',
      date: dateKey(day),
    );
    final b = await harness.store.flagsFor(
      employeeId: 'employee_b',
      date: dateKey(day),
    );
    expect(a.single.value, FlagValue.inside);
    expect(b.single.value, FlagValue.outside);
    expect(b.single.employeeId, 'employee_b');
  });

  test('outside then inside builds a return interval', () {
    final records = [
      _record(day, FlagValue.outside, AttendancePhase.working),
      _record(
        day.add(const Duration(minutes: 10)),
        FlagValue.inside,
        AttendancePhase.working,
      ),
    ];
    final intervals = outsideIntervals(records);
    expect(intervals.single.started, day);
    expect(intervals.single.returned, day.add(const Duration(minutes: 10)));
  });

  test('hour with outside only does not invent missing gaps', () {
    final dayStart = DateTime(day.year, day.month, day.day, 9);
    final checkIn = dayStart;
    final checkOut = DateTime(day.year, day.month, day.day, 18);
    final outside = _record(
      dayStart,
      FlagValue.outside,
      AttendancePhase.working,
    );
    final snapshots = missingOutsideHours(
      [outside],
      checkIn: checkIn,
      checkOut: checkOut,
      now: dayStart.add(const Duration(minutes: 10)),
    );
    expect(snapshots, isNotEmpty);
    expect(snapshots.first.summaryLabel, 'outside');
    final flags = snapshots.expand((s) => s.flags).toList();
    expect(flags.any((f) => f.kind == SlotKind.outside), isTrue);
    expect(flags.any((f) => f.kind == SlotKind.missing), isFalse);
  });

  test('status intervals cover outside then back in office', () {
    final dayStart = DateTime(day.year, day.month, day.day, 9);
    final records = [
      _record(dayStart, FlagValue.outside, AttendancePhase.working),
      _record(
        dayStart.add(const Duration(minutes: 5)),
        FlagValue.outside,
        AttendancePhase.working,
      ),
      _record(
        dayStart.add(const Duration(minutes: 10)),
        FlagValue.inside,
        AttendancePhase.working,
      ),
    ];
    final intervals = statusIntervals(
      records,
      checkIn: dayStart,
      checkOut: DateTime(day.year, day.month, day.day, 18),
      now: dayStart.add(const Duration(minutes: 15)),
    );
    expect(intervals.any((i) => i.kind == SlotKind.outside), isTrue);
    expect(intervals.any((i) => i.backInOffice), isTrue);
    expect(intervals.any((i) => i.kind == SlotKind.missing), isFalse);
  });

  test('timeline window is one hour before and after policy', () {
    const policy = PolicyWindow(
      checkInMinutes: 9 * 60,
      checkOutMinutes: 18 * 60,
    );
    expect(policy.onDay(day, policy.visualStartMinutes).hour, 8);
    expect(policy.onDay(day, policy.visualEndMinutes).hour, 19);
  });

  test('1am–11pm employee override keeps assigned times', () {
    const policy = PolicyWindow(
      checkInMinutes: 1 * 60,
      checkOutMinutes: 23 * 60,
      graceMinutes: 30,
    );
    expect(policy.checkInMinutes, 60);
    expect(policy.checkOutMinutes, 23 * 60);
    // ±1h clamps to the calendar day (12am–12am).
    expect(policy.visualStartMinutes, 0);
    expect(policy.visualEndMinutes, 24 * 60);
    expect(policy.onDay(day, policy.checkInMinutes).hour, 1);
    expect(policy.onDay(day, policy.checkOutMinutes).hour, 23);
  });

  test('flags are kept during the one hour grace before check in', () async {
    final harness = await start();
    final early = DateTime(2026, 9, 21, 8, 0);
    harness.engine.setClock(early);
    final record = await harness.engine.capture(
      sampleInside(harness.engine.offices[0], early),
    );
    expect(record, isNotNull);
    expect(record!.scheduledAt.hour, 8);
    expect(record.value, FlagValue.inside);
  });

  test('flags are kept during the one hour grace after check out', () async {
    final harness = await start();
    harness.engine.checkIn();
    final late = DateTime(2026, 9, 21, 18, 30);
    harness.engine.setClock(late);
    final record = await harness.engine.capture(
      sampleInside(harness.engine.offices[0], late),
    );
    expect(record, isNotNull);
    expect(record!.scheduledAt.hour, 18);
    expect(record.scheduledAt.minute, 30);
  });

  test('flags stop outside the grace window', () async {
    final harness = await start();
    harness.engine.setClock(DateTime(2026, 9, 21, 7, 55));
    expect(
      await harness.engine.capture(
        sampleInside(harness.engine.offices[0], harness.engine.now),
      ),
      isNull,
    );
    harness.engine.checkIn();
    harness.engine.setClock(DateTime(2026, 9, 21, 19, 0));
    expect(
      await harness.engine.capture(
        sampleInside(harness.engine.offices[0], harness.engine.now),
      ),
      isNull,
    );
  });

  test('resolved slots only include stored flags (no invented missing)', () {
    const policy = PolicyWindow(
      checkInMinutes: 9 * 60,
      checkOutMinutes: 18 * 60,
    );
    final start = policy.onDay(day, policy.visualStartMinutes);
    final end = policy.onDay(day, policy.visualEndMinutes);
    expect(
      resolvedSlots(
        const [],
        checkIn: start,
        checkOut: end,
        now: end.subtract(const Duration(minutes: 1)),
      ),
      isEmpty,
    );
    final stored = [
      _record(
        DateTime(day.year, day.month, day.day, 8, 0),
        FlagValue.inside,
        AttendancePhase.working,
      ),
      _record(
        DateTime(day.year, day.month, day.day, 18, 55),
        FlagValue.outside,
        AttendancePhase.working,
      ),
    ];
    final slots = resolvedSlots(
      stored,
      checkIn: start,
      checkOut: end,
      now: end.subtract(const Duration(minutes: 1)),
    );
    expect(slots.first.scheduledAt.hour, 8);
    expect(slots.first.scheduledAt.minute, 0);
    expect(slots.last.scheduledAt.hour, 18);
    expect(slots.last.scheduledAt.minute, 55);
    expect(slots, hasLength(2));
  });

  test('all true cycle stays in office and all false syncs', () {
    final inside = [_record(day, FlagValue.inside, AttendancePhase.working)];
    expect(evaluateCycle(inside).label, 'IN OFFICE');
    expect(evaluateCycle(inside).requiresServerSync, isFalse);
    final outside = [_record(day, FlagValue.outside, AttendancePhase.working)];
    expect(evaluateCycle(outside).label, 'LOCATION ISSUE');
    expect(evaluateCycle(outside).requiresServerSync, isTrue);
  });

  test('checkout time inside does not warn', () {
    final decision = decideAlert(
      value: FlagValue.inside,
      phase: AttendancePhase.working,
      officeName: 'Office A',
      checkoutTimeReached: true,
    );
    expect(decision.send, isFalse);
  });

  test('smart attendance auto check-in on enter', () {
    final offices = demoOffices();
    final match = matchOffices(sampleInside(offices[0], day), offices);
    final decision = decideSmartAttendance(
      settings: const SmartAttendanceSettings(
        premisesNotifications: true,
        smartAttendance: true,
      ),
      match: match,
      phase: AttendancePhase.notCheckedIn,
      policy: const PolicyWindow(
        checkInMinutes: 9 * 60,
        checkOutMinutes: 18 * 60,
      ),
      now: day,
      previousPresence: PresenceZone.outside,
    );
    expect(decision.autoPunch, AutoPunchKind.checkIn);
    expect(decision.skipPremisesBecauseAuto, isTrue);
    expect(decision.hasPremisesAlert, isFalse);
  });

  test('smart attendance auto check-in when already inside', () {
    final offices = demoOffices();
    final match = matchOffices(sampleInside(offices[0], day), offices);
    final stuck = decideSmartAttendance(
      settings: const SmartAttendanceSettings(smartAttendance: true),
      match: match,
      phase: AttendancePhase.notCheckedIn,
      policy: const PolicyWindow(
        checkInMinutes: 9 * 60,
        checkOutMinutes: 18 * 60,
      ),
      now: day,
      previousPresence: PresenceZone.inside,
    );
    expect(stuck.autoPunch, AutoPunchKind.checkIn);

    final firstFix = decideSmartAttendance(
      settings: const SmartAttendanceSettings(smartAttendance: true),
      match: match,
      phase: AttendancePhase.notCheckedIn,
      policy: const PolicyWindow(
        checkInMinutes: 9 * 60,
        checkOutMinutes: 18 * 60,
      ),
      now: day,
      previousPresence: null,
    );
    expect(firstFix.autoPunch, AutoPunchKind.checkIn);
  });

  test('premises reminder when smart off and inside not checked in', () {
    final offices = demoOffices();
    final match = matchOffices(sampleInside(offices[0], day), offices);
    final decision = decideSmartAttendance(
      settings: const SmartAttendanceSettings(
        premisesNotifications: true,
        smartAttendance: false,
      ),
      match: match,
      phase: AttendancePhase.notCheckedIn,
      policy: const PolicyWindow(
        checkInMinutes: 9 * 60,
        checkOutMinutes: 18 * 60,
      ),
      now: day,
      previousPresence: null,
    );
    expect(decision.autoPunch, isNull);
    expect(decision.hasPremisesAlert, isTrue);
    expect(decision.premisesAlert!.type, AlertType.premisesCheckIn);
  });

  test('premises reminder is once per 5-minute slot after dismiss/resume', () {
    final slot = DateTime(2026, 9, 21, 10, 3);
    final prior = FlagAlert(
      id: 'al_1',
      employeeId: 'employee_a',
      attendanceSessionId: 'sess',
      flagEventId: 'e1',
      cycleId: 'c1',
      timestamp: slot,
      type: AlertType.premisesCheckIn,
      locationStatus: FlagValue.inside,
      message: 'please check in',
    );
    expect(
      premisesNotifiedInSlot(
        type: AlertType.premisesCheckIn,
        now: slot.add(const Duration(minutes: 1)),
        existingAlerts: [prior],
      ),
      isTrue,
    );
    expect(
      premisesNotifiedInSlot(
        type: AlertType.premisesCheckIn,
        now: slot.add(const Duration(minutes: 5)),
        existingAlerts: [prior],
      ),
      isFalse,
    );
    expect(
      premisesNotifiedInSlot(
        type: AlertType.premisesCheckIn,
        now: slot,
        lastNotifySlot: slotStart(slot),
        lastNotifyType: AlertType.premisesCheckIn,
      ),
      isTrue,
    );
  });

  test('leave auto checkout ignores grace', () {
    final decision = decideSmartAttendance(
      settings: const SmartAttendanceSettings(smartAttendance: true),
      match: const MatchResult(value: FlagValue.outside, comparisons: []),
      phase: AttendancePhase.working,
      policy: const PolicyWindow(
        checkInMinutes: 9 * 60,
        checkOutMinutes: 18 * 60,
        graceMinutes: 30,
      ),
      now: DateTime(2026, 9, 21, 18, 10),
      previousPresence: PresenceZone.inside,
    );
    expect(decision.autoPunch, AutoPunchKind.checkOut);
  });

  test('unavailable location does not auto punch', () {
    final decision = decideSmartAttendance(
      settings: const SmartAttendanceSettings(
        premisesNotifications: true,
        smartAttendance: true,
      ),
      match: const MatchResult(value: FlagValue.unavailable, comparisons: []),
      phase: AttendancePhase.notCheckedIn,
      policy: const PolicyWindow(
        checkInMinutes: 9 * 60,
        checkOutMinutes: 18 * 60,
      ),
      now: day,
      previousPresence: PresenceZone.outside,
    );
    expect(decision.autoPunch, isNull);
    expect(decision.hasPremisesAlert, isFalse);
  });
}

LocationFlagRecord _record(
  DateTime time,
  FlagValue value,
  AttendancePhase phase,
) {
  return LocationFlagRecord(
    eventId: 'e${time.millisecondsSinceEpoch}',
    employeeId: 'employee_a',
    attendanceSessionId: 'sess',
    date: dateKey(time),
    scheduledAt: time,
    capturedAt: time,
    flagNumber: flagNumberFor(time),
    cycleId: cycleIdFor(time),
    cycleStart: cycleStartFor(time),
    cycleEnd: cycleEndFor(time),
    value: value,
    kind: value == FlagValue.inside ? SlotKind.inside : SlotKind.outside,
    phase: phase,
    checkInStatus: true,
    breakStatus: false,
    checkOutStatus: false,
    violation: value == FlagValue.outside,
    syncState: SyncState.local,
  );
}
