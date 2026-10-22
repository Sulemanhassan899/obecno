import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';

void main() {
  test('open re-check-in keeps first check-in; checkout stays latest closed', () {
    final events = [
      AttendanceEvent(
        id: '1',
        type: AttendanceEventType.checkIn,
        time: DateTime(2026, 10, 19, 14, 38),
      ),
      AttendanceEvent(
        id: '2',
        type: AttendanceEventType.checkOut,
        time: DateTime(2026, 10, 19, 15, 32),
      ),
      AttendanceEvent(
        id: '3',
        type: AttendanceEventType.checkIn,
        time: DateTime(2026, 10, 19, 20, 22),
      ),
    ];

    final summary = AttendanceEngine.compute(events);
    final now = DateTime(2026, 10, 19, 22, 7);

    // Card header: first in of the day, latest completed out.
    expect(summary.displayCheckIn, DateTime(2026, 10, 19, 14, 38));
    expect(summary.displayCheckOut, DateTime(2026, 10, 19, 15, 32));
    expect(summary.liveWorkingDuration(now: now), const Duration(hours: 2, minutes: 39));
  });

  test('check-in stays first punch while check-out advances across outs', () {
    // 1:40 PM in → out -- → 5:00 → 8:00 → 10:00; check-in never moves.
    final firstIn = DateTime(2026, 10, 20, 13, 40);

    AttendanceSummary summaryFor(List<AttendanceEvent> events) =>
        AttendanceEngine.compute(events);

    final openOnly = summaryFor([
      AttendanceEvent(
        id: '1',
        type: AttendanceEventType.checkIn,
        time: firstIn,
      ),
    ]);
    expect(openOnly.displayCheckIn, firstIn);
    expect(openOnly.displayCheckOut, isNull);

    final out5 = summaryFor([
      AttendanceEvent(
        id: '1',
        type: AttendanceEventType.checkIn,
        time: firstIn,
      ),
      AttendanceEvent(
        id: '2',
        type: AttendanceEventType.checkOut,
        time: DateTime(2026, 10, 20, 17),
      ),
    ]);
    expect(out5.displayCheckIn, firstIn);
    expect(out5.displayCheckOut, DateTime(2026, 10, 20, 17));

    final out8 = summaryFor([
      AttendanceEvent(
        id: '1',
        type: AttendanceEventType.checkIn,
        time: firstIn,
      ),
      AttendanceEvent(
        id: '2',
        type: AttendanceEventType.checkOut,
        time: DateTime(2026, 10, 20, 17),
      ),
      AttendanceEvent(
        id: '3',
        type: AttendanceEventType.checkIn,
        time: DateTime(2026, 10, 20, 17, 30),
      ),
      AttendanceEvent(
        id: '4',
        type: AttendanceEventType.checkOut,
        time: DateTime(2026, 10, 20, 20),
      ),
    ]);
    expect(out8.displayCheckIn, firstIn);
    expect(out8.displayCheckOut, DateTime(2026, 10, 20, 20));

    final out10Open = summaryFor([
      AttendanceEvent(
        id: '1',
        type: AttendanceEventType.checkIn,
        time: firstIn,
      ),
      AttendanceEvent(
        id: '2',
        type: AttendanceEventType.checkOut,
        time: DateTime(2026, 10, 20, 17),
      ),
      AttendanceEvent(
        id: '3',
        type: AttendanceEventType.checkIn,
        time: DateTime(2026, 10, 20, 17, 30),
      ),
      AttendanceEvent(
        id: '4',
        type: AttendanceEventType.checkOut,
        time: DateTime(2026, 10, 20, 20),
      ),
      AttendanceEvent(
        id: '5',
        type: AttendanceEventType.checkIn,
        time: DateTime(2026, 10, 20, 20, 15),
      ),
      AttendanceEvent(
        id: '6',
        type: AttendanceEventType.checkOut,
        time: DateTime(2026, 10, 20, 22),
      ),
      AttendanceEvent(
        id: '7',
        type: AttendanceEventType.checkIn,
        time: DateTime(2026, 10, 20, 22, 10),
      ),
    ]);
    expect(out10Open.displayCheckIn, firstIn);
    expect(out10Open.displayCheckOut, DateTime(2026, 10, 20, 22));
    expect(out10Open.isCheckedIn, isTrue);
  });
}
