import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';

void main() {
  DateTime t(int hour, [int minute = 0]) => DateTime(2026, 9, 21, hour, minute);

  LocationFlagObservation obs(
    DateTime at,
    bool? inside, {
    bool checkedIn = true,
    bool onBreak = false,
    bool checkedOut = false,
  }) {
    return LocationFlagObservation(
      at: at,
      inside: inside,
      checkInStatus: checkedIn,
      breakStatus: onBreak,
      checkOutStatus: checkedOut,
    );
  }

  group('interval and cycle', () {
    test('uses 5 minute flags and 12 flags per hour', () {
      expect(LocationFlagEvaluator.flagInterval, const Duration(minutes: 5));
      expect(LocationFlagEvaluator.flagsPerCycle, 12);
    });

    test('flag numbers align to every 5 minutes', () {
      expect(LocationFlagEvaluator.flagNumberFor(t(9)), 1);
      expect(LocationFlagEvaluator.flagNumberFor(t(9, 4)), 1);
      expect(LocationFlagEvaluator.flagNumberFor(t(9, 5)), 2);
      expect(LocationFlagEvaluator.flagNumberFor(t(9, 15)), 4);
      expect(LocationFlagEvaluator.flagNumberFor(t(9, 30)), 7);
      expect(LocationFlagEvaluator.flagNumberFor(t(9, 55)), 12);
      expect(LocationFlagEvaluator.flagNumberFor(t(10)), 1);
    });

    test('cycle ids do not mix hours or employees', () {
      final a9 = LocationFlagEvaluator.cycleIdFor(
        employeeId: 'emp-a',
        at: t(9, 45),
      );
      final a10 = LocationFlagEvaluator.cycleIdFor(
        employeeId: 'emp-a',
        at: t(10),
      );
      final b9 = LocationFlagEvaluator.cycleIdFor(
        employeeId: 'emp-b',
        at: t(9, 45),
      );
      expect(a9, isNot(a10));
      expect(a9, isNot(b9));
      expect(a9, contains('emp-a'));
      expect(a9, contains('09'));
    });

    test('next aligned check is the following 5 minute slot', () {
      expect(LocationFlagEvaluator.nextAlignedCheck(t(9)), t(9, 5));
      expect(LocationFlagEvaluator.nextAlignedCheck(t(9, 1)), t(9, 5));
      expect(LocationFlagEvaluator.nextAlignedCheck(t(9, 55)), t(10));
    });
  });

  group('radius', () {
    test('distance equal to radius is inside', () {
      expect(LocationFlagEvaluator.isInsideRadius(100, 100), isTrue);
    });

    test('distance greater than radius is outside', () {
      expect(LocationFlagEvaluator.isInsideRadius(100.1, 100), isFalse);
    });
  });

  group('status rules', () {
    test('not checked in is never a location violation', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: false,
        observations: [
          obs(t(8), false, checkedIn: false),
          obs(t(8, 15), false, checkedIn: false),
          obs(t(8, 30), false, checkedIn: false),
          obs(t(8, 45), false, checkedIn: false),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.notCheckedIn);
      expect(verdict.requiresServerSync, isFalse);
    });

    test('ALL TRUE is in office and does not require sync', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: true,
        observations: [
          obs(t(9), true),
          obs(t(9, 15), true),
          obs(t(9, 30), true),
          obs(t(9, 45), true),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.inOffice);
      expect(verdict.requiresServerSync, isFalse);
    });

    test('ALL FALSE is a location issue and requires sync', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: true,
        observations: [
          obs(t(9), false),
          obs(t(9, 15), false),
          obs(t(9, 30), false),
          obs(t(9, 45), false),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.locationIssue);
      expect(verdict.requiresServerSync, isTrue);
    });

    test('NULL is not treated as FALSE', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: true,
        observations: [
          obs(t(9), true),
          obs(t(9, 15), null),
          obs(t(9, 30), true),
          obs(t(9, 45), true),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.inOffice);
      expect(verdict.requiresServerSync, isFalse);
    });

    test('all NULL is location unavailable, not an issue', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: true,
        observations: [
          obs(t(9), null),
          obs(t(9, 15), null),
          obs(t(9, 30), null),
          obs(t(9, 45), null),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.locationUnavailable);
      expect(verdict.requiresServerSync, isFalse);
    });

    test('break FALSE is not a working-time location issue', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: true,
        observations: [
          obs(t(13), true),
          obs(t(13, 15), true),
          obs(t(13, 30), false, onBreak: true),
          obs(t(13, 45), false, onBreak: true),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.inOffice);
      expect(verdict.requiresServerSync, isFalse);
    });

    test('FALSE after break out still requires sync; status follows latest', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: true,
        observations: [
          obs(t(14), false),
          obs(t(14, 15), false),
          obs(t(14, 30), false),
          obs(t(14, 45), true),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.inOffice);
      expect(verdict.requiresServerSync, isTrue);
    });

    test('current status follows the latest flag after returning inside', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: true,
        observations: [
          obs(t(14, 15), false),
          obs(t(14, 20), true),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.inOffice);
      expect(verdict.requiresServerSync, isTrue);
    });

    test('current status is location issue while latest flag is FALSE', () {
      final verdict = LocationFlagEvaluator.evaluate(
        checkInStatus: true,
        observations: [
          obs(t(14, 10), true),
          obs(t(14, 15), false),
        ],
      );
      expect(verdict.status, LocationFlagUiStatus.locationIssue);
      expect(verdict.requiresServerSync, isTrue);
    });
  });

  group('all 16 TRUE/FALSE combinations', () {
    final cases = <List<bool>>[
      [true, true, true, true],
      [true, true, true, false],
      [true, true, false, true],
      [true, true, false, false],
      [true, false, true, true],
      [true, false, true, false],
      [true, false, false, true],
      [true, false, false, false],
      [false, true, true, true],
      [false, true, true, false],
      [false, true, false, true],
      [false, true, false, false],
      [false, false, true, true],
      [false, false, true, false],
      [false, false, false, true],
      [false, false, false, false],
    ];

    test('every combination is classified', () {
      expect(cases, hasLength(16));
      for (final flags in cases) {
        final observations = [
          obs(t(9), flags[0]),
          obs(t(9, 15), flags[1]),
          obs(t(9, 30), flags[2]),
          obs(t(9, 45), flags[3]),
        ];
        final verdict = LocationFlagEvaluator.evaluate(
          checkInStatus: true,
          observations: observations,
        );
        final anyFalse = flags.any((flag) => !flag);
        final latest = flags.last;
        expect(
          verdict.status,
          latest
              ? LocationFlagUiStatus.inOffice
              : LocationFlagUiStatus.locationIssue,
          reason: '$flags status should follow latest flag ($latest)',
        );
        expect(
          verdict.requiresServerSync,
          anyFalse,
          reason: '$flags sync should track any FALSE',
        );
      }
    });
  });

  group('policy window', () {
    test('uses permission times and is not hardcoded', () {
      final window = LocationFlagEvaluator.policyWindow(
        day: DateTime(2026, 9, 21),
        checkInRaw: '08:30 AM',
        checkOutRaw: '05:15 PM',
      );
      expect(window.start, DateTime(2026, 9, 21, 8, 30));
      expect(window.end, DateTime(2026, 9, 21, 17, 15));
    });

    test('parses 24-hour times with seconds from backend policy', () {
      final window = LocationFlagEvaluator.policyWindow(
        day: DateTime(2026, 9, 21),
        checkInRaw: '09:00:00',
        checkOutRaw: '18:00:00',
      );
      expect(window.start, DateTime(2026, 9, 21, 9));
      expect(window.end, DateTime(2026, 9, 21, 18));
      expect(window.duration, const Duration(hours: 9));
    });

    test('overnight checkout rolls to the next day', () {
      final window = LocationFlagEvaluator.policyWindow(
        day: DateTime(2026, 9, 21),
        checkInRaw: '09:00 PM',
        checkOutRaw: '06:00 AM',
      );
      expect(window.end.day, 22);
    });

    test('padded window adds one hour before check-in and after checkout', () {
      final window = LocationFlagEvaluator.policyWindow(
        day: DateTime(2026, 9, 21),
        checkInRaw: '09:00:00',
        checkOutRaw: '18:00:00',
      );
      final padded = window.padded();
      expect(padded.start, DateTime(2026, 9, 21, 8));
      expect(padded.end, DateTime(2026, 9, 21, 19));
      expect(window.start, DateTime(2026, 9, 21, 9));
      expect(window.end, DateTime(2026, 9, 21, 18));
    });
  });
}
