import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_event.dart'
    hide AttendanceFormat;
import 'package:obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 8, 13);

  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  group('Scenario 1 — single session', () {
    test('history engine keeps first in / last out', () {
      final events = [
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkIn,
          time: at(10, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkOut,
          time: at(11, 57),
        ),
      ];
      final summary = HistoryAttendanceEngine.compute(events);
      expect(summary.firstCheckIn, at(10, 57));
      expect(summary.lastCheckOut, at(11, 57));
    });
  });

  group('Scenario 2 — multiple sessions', () {
    test('later check-ins do not overwrite first check-in', () {
      final events = [
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkIn,
          time: at(10, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkOut,
          time: at(11, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkIn,
          time: at(12, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkOut,
          time: at(15, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkIn,
          time: at(16, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkOut,
          time: at(17, 57),
        ),
      ];
      final summary = HistoryAttendanceEngine.compute(events);
      expect(summary.firstCheckIn, at(10, 57));
      expect(summary.lastCheckOut, at(17, 57));
      expect(summary.isCheckedIn, isFalse);
      expect(summary.totalWorkingDuration, at(17, 57).difference(at(10, 57)));
    });

    test('clock engine matches history engine', () {
      final events = [
        AttendanceEvent(
          id: '1',
          type: AttendanceEventType.checkIn,
          time: at(10, 57),
        ),
        AttendanceEvent(
          id: '2',
          type: AttendanceEventType.checkOut,
          time: at(11, 57),
        ),
        AttendanceEvent(
          id: '3',
          type: AttendanceEventType.checkIn,
          time: at(12, 57),
        ),
        AttendanceEvent(
          id: '4',
          type: AttendanceEventType.checkOut,
          time: at(15, 57),
        ),
        AttendanceEvent(
          id: '5',
          type: AttendanceEventType.checkIn,
          time: at(16, 57),
        ),
        AttendanceEvent(
          id: '6',
          type: AttendanceEventType.checkOut,
          time: at(17, 57),
        ),
      ];
      final summary = AttendanceEngine.compute(events);
      expect(summary.firstCheckIn, at(10, 57));
      expect(summary.lastCheckOut, at(17, 57));
      expect(summary.totalWorkingDuration, at(17, 57).difference(at(10, 57)));
    });
  });

  group('Header duration matches displayed first in / last out', () {
    test('5:59 PM to 6:35 PM is 36 minutes, not in-office leftover 12', () {
      final events = [
        AttendanceEvent(
          id: '1',
          type: AttendanceEventType.checkIn,
          time: at(17, 59),
        ),
        AttendanceEvent(
          id: '2',
          type: AttendanceEventType.checkOut,
          time: at(18, 11),
        ),
        AttendanceEvent(
          id: '3',
          type: AttendanceEventType.checkIn,
          time: at(18, 28),
        ),
        AttendanceEvent(
          id: '4',
          type: AttendanceEventType.checkOut,
          time: at(18, 35),
        ),
      ];
      final summary = AttendanceEngine.compute(events);
      expect(summary.firstCheckIn, at(17, 59));
      expect(summary.lastCheckOut, at(18, 35));
      expect(summary.totalWorkingDuration, const Duration(minutes: 36));
      expect(
        summary.liveWorkingDuration(now: at(21, 6)),
        const Duration(minutes: 36),
      );
    });

    test('does not sum only in-office sessions', () {
      final events = [
        AttendanceEvent(
          id: '1',
          type: AttendanceEventType.checkIn,
          time: at(17, 59),
        ),
        AttendanceEvent(
          id: '2',
          type: AttendanceEventType.checkOut,
          time: at(18, 6),
        ),
        AttendanceEvent(
          id: '3',
          type: AttendanceEventType.checkIn,
          time: at(18, 28),
        ),
        AttendanceEvent(
          id: '4',
          type: AttendanceEventType.checkOut,
          time: at(18, 31),
        ),
      ];
      final summary = AttendanceEngine.compute(events);
      expect(summary.firstCheckIn, at(17, 59));
      expect(summary.lastCheckOut, at(18, 31));
      expect(summary.totalWorkingDuration, const Duration(minutes: 32));
      expect(
        summary.liveWorkingDuration(now: at(21, 2)),
        const Duration(minutes: 32),
      );
    });

    test('live duration spans first check-in to now while still in', () {
      final events = [
        AttendanceEvent(
          id: '1',
          type: AttendanceEventType.checkIn,
          time: at(17, 59),
        ),
        AttendanceEvent(
          id: '2',
          type: AttendanceEventType.checkOut,
          time: at(18, 6),
        ),
        AttendanceEvent(
          id: '3',
          type: AttendanceEventType.checkIn,
          time: at(18, 28),
        ),
      ];
      final summary = AttendanceEngine.compute(events);
      expect(summary.isCheckedIn, isTrue);
      expect(
        summary.liveWorkingDuration(now: at(21, 2)),
        at(21, 2).difference(at(17, 59)),
      );
    });
  });

  group('Scenario 3 — break between sessions', () {
    test('breaks do not change first in / last out', () {
      final events = [
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkIn,
          time: at(10, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkOut,
          time: at(11, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkIn,
          time: at(12, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.breakStart,
          time: at(13, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.breakEnd,
          time: at(14, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkOut,
          time: at(15, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkIn,
          time: at(16, 57),
        ),
        HistoryAttendanceEvent(
          type: AttendanceHisotryEventType.checkOut,
          time: at(17, 57),
        ),
      ];
      final summary = HistoryAttendanceEngine.compute(events);
      expect(summary.firstCheckIn, at(10, 57));
      expect(summary.lastCheckOut, at(17, 57));
      expect(summary.totalBreakDuration, const Duration(hours: 1));
      expect(
        summary.totalWorkingDuration,
        at(17, 57).difference(at(10, 57)) - const Duration(hours: 1),
      );
    });
  });

  group('Scenario 4 — reverse API order', () {
    test('AttendanceDay.firstCheckIn / lastCheckOut ignore list order', () {
      final dayModel = AttendanceDay(
        date: day,
        checkIns: const ['16:57:00', '10:57:00', '12:57:00'],
        checkOuts: const ['11:57:00', '17:57:00', '15:57:00'],
      );
      expect(dayModel.firstCheckIn, '10:57:00');
      expect(dayModel.lastCheckOut, '17:57:00');
    });

    test('fromApiHistoryItem sorts check-in/out pairs', () {
      final dayModel = AttendanceDay.fromApiHistoryItem({
        'date': '2026-08-13',
        'id': 1,
        'attendance_details': [
          {'type': 'check in', 'attendance_time': '16:57:00'},
          {'type': 'check out', 'attendance_time': '17:57:00'},
          {'type': 'check in', 'attendance_time': '10:57:00'},
          {'type': 'check out', 'attendance_time': '11:57:00'},
        ],
      });
      expect(dayModel.checkIns.first, '10:57:00');
      expect(dayModel.checkOuts.last, '17:57:00');
      expect(dayModel.firstCheckIn, '10:57:00');
      expect(dayModel.lastCheckOut, '17:57:00');
    });
  });

  group('12-hour AM/PM working hours', () {
    test('parses 12:25 AM as hour 0 and 8:00 PM as hour 20', () {
      final day = DateTime(2026, 9, 10);
      final checkIn = AttendanceEditRequest.parseClockTime(
        '12:25 AM',
        date: day,
      )!;
      final checkOut = AttendanceEditRequest.parseClockTime(
        '8:00 PM',
        date: day,
      )!;
      expect(checkIn.hour, 0);
      expect(checkIn.minute, 25);
      expect(checkOut.hour, 20);
      expect(checkOut.minute, 0);
      expect(
        AttendanceFormat.workedDuration(
          start: checkIn,
          end: checkOut,
          breaks: const Duration(hours: 1),
        ),
        const Duration(hours: 18, minutes: 35),
      );
    });

    test('12:25 AM to 8:00 PM minus 1h break is 18h 35m', () {
      final events = [
        AttendanceEvent(
          id: '1',
          type: AttendanceEventType.checkIn,
          time: at(0, 25),
        ),
        AttendanceEvent(
          id: '2',
          type: AttendanceEventType.breakStart,
          time: at(13, 0),
        ),
        AttendanceEvent(
          id: '3',
          type: AttendanceEventType.breakEnd,
          time: at(14, 0),
        ),
        AttendanceEvent(
          id: '4',
          type: AttendanceEventType.checkOut,
          time: at(20, 0),
        ),
      ];
      final summary = AttendanceEngine.compute(events);
      expect(summary.firstCheckIn, at(0, 25));
      expect(summary.lastCheckOut, at(20, 0));
      expect(summary.totalBreakDuration, const Duration(hours: 1));
      expect(
        summary.totalWorkingDuration,
        const Duration(hours: 18, minutes: 35),
      );
    });

    test('live duration from 12:25 AM to 8:17 PM while still checked in', () {
      final events = [
        AttendanceEvent(
          id: '1',
          type: AttendanceEventType.checkIn,
          time: at(0, 25),
        ),
      ];
      final summary = AttendanceEngine.compute(events);
      expect(
        summary.liveWorkingDuration(now: at(20, 17)),
        const Duration(hours: 19, minutes: 52),
      );
    });

    test('12:25 AM to 8:25 PM minus 1h break is 19h', () {
      final events = [
        AttendanceEvent(
          id: '1',
          type: AttendanceEventType.checkIn,
          time: at(0, 25),
        ),
        AttendanceEvent(
          id: '2',
          type: AttendanceEventType.breakStart,
          time: at(13, 0),
        ),
        AttendanceEvent(
          id: '3',
          type: AttendanceEventType.breakEnd,
          time: at(14, 0),
        ),
        AttendanceEvent(
          id: '4',
          type: AttendanceEventType.checkOut,
          time: at(20, 25),
        ),
      ];
      final summary = AttendanceEngine.compute(events);
      expect(AttendanceFormat.time(summary.firstCheckIn), '12:25 AM');
      expect(AttendanceFormat.time(summary.lastCheckOut), '8:25 PM');
      expect(summary.totalWorkingDuration, const Duration(hours: 19));
      expect(
        AttendanceFormat.duration(summary.totalWorkingDuration),
        '19h 00m',
      );
    });

    test('UTC midnight stamp still counts as 12:25 AM wall clock', () {
      final checkIn = DateTime.utc(2026, 8, 13, 0, 25);
      final checkOut = DateTime(2026, 8, 13, 20, 25);
      expect(AttendanceFormat.time(checkIn), '12:25 AM');
      expect(AttendanceFormat.time(checkOut), '8:25 PM');
      expect(
        AttendanceFormat.workedDuration(
          start: checkIn,
          end: checkOut,
          breaks: const Duration(hours: 1),
        ),
        const Duration(hours: 19),
      );
    });

    test('hourTo24 maps 12 AM to 0 and 8 PM to 20', () {
      expect(AttendanceEditRequest.hourTo24(12, isPm: false), 0);
      expect(AttendanceEditRequest.hourTo24(12, isPm: true), 12);
      expect(AttendanceEditRequest.hourTo24(8, isPm: true), 20);
      expect(AttendanceEditRequest.hourTo24(8, isPm: false), 8);
    });
  });

  group('Timeline order', () {
    test(
      'newest punch is first so 5:25 PM checkout sits above 1:20 PM check-in',
      () {
        final events = [
          HistoryAttendanceEvent(
            type: AttendanceHisotryEventType.checkIn,
            time: at(13, 20),
          ),
          HistoryAttendanceEvent(
            type: AttendanceHisotryEventType.breakStart,
            time: at(13, 17),
          ),
          HistoryAttendanceEvent(
            type: AttendanceHisotryEventType.breakEnd,
            time: at(14, 17),
          ),
          HistoryAttendanceEvent(
            type: AttendanceHisotryEventType.checkOut,
            time: at(17, 25),
          ),
        ];
        final timeline = HistoryAttendanceEngine.sortedNewestFirst(events);
        expect(timeline.map((e) => e.type).toList(), [
          AttendanceHisotryEventType.checkOut,
          AttendanceHisotryEventType.breakEnd,
          AttendanceHisotryEventType.checkIn,
          AttendanceHisotryEventType.breakStart,
        ]);
      },
    );
  });
}
