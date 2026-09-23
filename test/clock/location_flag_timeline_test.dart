import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/demo/location_flags/data/location_flag_demo_scenarios.dart';
import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_timeline.dart';

void main() {
  final window = PolicyDayWindow(
    start: DateTime(2026, 9, 21, 9),
    end: DateTime(2026, 9, 21, 18),
  );

  LocationFlagObservation obs(
    DateTime at,
    bool? inside, {
    bool onBreak = false,
    bool checkedIn = true,
  }) {
    return LocationFlagObservation(
      at: at,
      inside: inside,
      checkInStatus: checkedIn,
      breakStatus: onBreak,
      checkOutStatus: false,
    );
  }

  test('multiple outside intervals stay separate', () {
    final observations = [
      obs(DateTime(2026, 9, 21, 10, 30), false),
      obs(DateTime(2026, 9, 21, 10, 45), true),
      obs(DateTime(2026, 9, 21, 12), false),
      obs(DateTime(2026, 9, 21, 12, 15), false),
      obs(DateTime(2026, 9, 21, 12, 30), true),
      obs(DateTime(2026, 9, 21, 15), false),
      obs(DateTime(2026, 9, 21, 15, 15), true),
    ];

    final intervals = LocationFlagTimeline.outsideIntervals(
      observations: observations,
    );
    expect(intervals, hasLength(3));
    expect(intervals[0].wentOutsideAt, DateTime(2026, 9, 21, 10, 30));
    expect(intervals[0].returnedAt, DateTime(2026, 9, 21, 10, 45));
    expect(intervals[1].wentOutsideAt, DateTime(2026, 9, 21, 12));
    expect(intervals[1].returnedAt, DateTime(2026, 9, 21, 12, 30));
    expect(intervals[2].wentOutsideAt, DateTime(2026, 9, 21, 15));
    expect(intervals[2].returnedAt, DateTime(2026, 9, 21, 15, 15));
  });

  test('NULL unrecorded slots are a distinct unknown segment', () {
    final segments = LocationFlagTimeline.segments(
      window: window,
      observations: [
        obs(DateTime(2026, 9, 21, 9), true),
        obs(DateTime(2026, 9, 21, 9, 15), null),
        obs(DateTime(2026, 9, 21, 9, 30), false),
      ],
    );
    expect(segments.map((s) => s.kind), [
      LocationTimelineKind.inside,
      LocationTimelineKind.unknown,
      LocationTimelineKind.outside,
    ]);
  });

  test('missing flags between checks are orange/unknown', () {
    final segments = LocationFlagTimeline.segments(
      window: window,
      observations: [
        obs(DateTime(2026, 9, 21, 9), true),
        obs(DateTime(2026, 9, 21, 10), false),
      ],
      until: DateTime(2026, 9, 21, 10, 5),
      fillMissing: true,
    );
    expect(segments.first.kind, LocationTimelineKind.inside);
    expect(segments.first.end, DateTime(2026, 9, 21, 9, 5));
    expect(
      segments.where((s) => s.kind == LocationTimelineKind.unknown),
      isNotEmpty,
    );
    expect(segments.last.kind, LocationTimelineKind.outside);
  });

  test('missing fill applies in the padded hour before check-in', () {
    final working = window;
    final padded = working.padded();
    final segments = LocationFlagTimeline.segments(
      window: padded,
      observations: [
        obs(DateTime(2026, 9, 21, 9), true),
      ],
      until: DateTime(2026, 9, 21, 9, 20),
      fillMissing: true,
    );
    expect(segments.first.start, DateTime(2026, 9, 21, 8));
    expect(segments.first.kind, LocationTimelineKind.unknown);
    expect(
      segments.any(
        (s) =>
            s.kind == LocationTimelineKind.inside &&
            s.start == DateTime(2026, 9, 21, 9),
      ),
      isTrue,
    );
  });

  test('break observations are distinct from working outside', () {
    final segments = LocationFlagTimeline.segments(
      window: window,
      observations: [
        obs(DateTime(2026, 9, 21, 13), true),
        obs(DateTime(2026, 9, 21, 13, 30), false, onBreak: true),
      ],
    );
    expect(segments.last.kind, LocationTimelineKind.onBreak);
  });

  test('default demo day has two outside intervals', () {
    final observations = LocationFlagDemoScenarios.defaultWorkingDay(window);
    final intervals = LocationFlagTimeline.outsideIntervals(
      observations: observations,
    );
    expect(intervals, hasLength(2));
    expect(intervals.first.wentOutsideAt.hour, 10);
    expect(intervals.first.wentOutsideAt.minute, 30);
    expect(intervals.last.wentOutsideAt.hour, 14);
  });

  test('axis marks are leave/return times, not interval ticks', () {
    final hour = PolicyDayWindow(
      start: DateTime(2026, 9, 21, 10),
      end: DateTime(2026, 9, 21, 11),
    );
    final marks = LocationFlagTimeline.axisMarks(
      window: hour,
      intervals: [
        LocationOutsideInterval(
          wentOutsideAt: DateTime(2026, 9, 21, 10),
          returnedAt: DateTime(2026, 9, 21, 10, 15),
        ),
        LocationOutsideInterval(
          wentOutsideAt: DateTime(2026, 9, 21, 10, 55),
        ),
      ],
    );

    expect(
      marks.map((m) => (m.kind, m.at.hour, m.at.minute)).toList(),
      [
        (LocationTimelineMarkKind.start, 10, 0),
        (LocationTimelineMarkKind.returned, 10, 15),
        (LocationTimelineMarkKind.leftOffice, 10, 55),
        (LocationTimelineMarkKind.end, 11, 0),
      ],
    );
  });

  test('not-checked-in demo data does not create a violation', () {
    final observations = LocationFlagDemoScenarios.notCheckedIn(window);
    final verdict = LocationFlagEvaluator.evaluate(
      checkInStatus: false,
      observations: observations,
    );
    expect(verdict.status, LocationFlagUiStatus.notCheckedIn);
    expect(
      LocationFlagTimeline.outsideIntervals(observations: observations),
      isEmpty,
    );
  });
}
