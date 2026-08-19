import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';
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
}
