import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/constants/app_enums.dart'
    hide AttendanceActionResult;
import 'package:obecno/features/clock/clocks/clocks.dart';
import 'package:obecno/features/clock/domain/controllers/clock_controller.dart';
import 'package:obecno/features/clock/services/employee_trusted_time.dart';
import 'package:obecno/features/clock/services/trusted_time_session.dart';
import 'package:obecno/features/clock/services/trusted_time_store.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_history_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mon 7 Sep 2026 → Sun 13 Sep 2026. Default policy is Mon–Fri.
  final week = [
    DateTime(2026, 9, 7, 10), // Monday
    DateTime(2026, 9, 8, 10), // Tuesday
    DateTime(2026, 9, 9, 10), // Wednesday
    DateTime(2026, 9, 10, 10), // Thursday
    DateTime(2026, 9, 11, 10), // Friday
    DateTime(2026, 9, 12, 10), // Saturday
    DateTime(2026, 9, 13, 10), // Sunday
  ];

  const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<ClockScreenController> controllerAt(DateTime now) async {
    SharedPreferences.setMockInitialValues({});
    final session = TrustedTimeSession(
      monotonicClock: FakeMonotonicClock(),
      wallClock: FakeWallClock(now),
      store: InMemoryTrustedTimeStore(),
    );
    await session.restore();
    await session.login();

    final trusted = EmployeeTrustedTime(session: session);
    await trusted.init();

    return ClockScreenController(userId: 'emp-week', trustedTime: trusted);
  }

  group('Clock: punch on every day of the week', () {
    for (final now in week) {
      final name = weekdayNames[now.weekday - 1];
      test('check-in is allowed on $name', () async {
        final controller = await controllerAt(now);
        addTearDown(controller.dispose);

        expect(controller.clockNow.weekday, now.weekday);
        expect(
          controller.isTodayWorkingDay,
          now.weekday >= DateTime.monday && now.weekday <= DateTime.friday,
        );

        final result = await controller.handleMainTap();

        expect(result, AttendanceActionResult.checkedIn);
        expect(controller.effectiveStatus, AttendanceDayStatus.checkedIn);
        expect(
          controller.events.map((e) => e.type),
          [AttendanceEventType.checkIn],
        );
      });
    }
  });

  group('Clock: no punch on every day of the week', () {
    for (final now in week) {
      final name = weekdayNames[now.weekday - 1];
      test('no check-in on $name stays checked out', () async {
        final controller = await controllerAt(now);
        addTearDown(controller.dispose);

        expect(controller.clockNow.weekday, now.weekday);
        expect(controller.effectiveStatus, AttendanceDayStatus.checkedOut);
        expect(controller.events, isEmpty);
        expect(controller.hasAnyEventToday, isFalse);
      });
    }
  });

  group('Attendance calendar: full week without punching', () {
    test('Mon–Fri are absent and Sat–Sun are weekend', () {
      final classified = DayClassificationEngine.classifyWeek(
        weekStart: DateTime(2026, 9, 7),
        workingWeekdays: {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        },
        attendanceDates: const {},
        holidays: const [],
      );

      expect(classified.map((day) => day.type), [
        DayCardType.absent,
        DayCardType.absent,
        DayCardType.absent,
        DayCardType.absent,
        DayCardType.absent,
        DayCardType.weekend,
        DayCardType.weekend,
      ]);
    });
  });

  group('Attendance calendar: full week with punching', () {
    test('punched weekdays are worked; punched weekend stays weekend', () {
      final punched = {
        for (final day in week)
          DateTime(day.year, day.month, day.day),
      };

      final classified = DayClassificationEngine.classifyWeek(
        weekStart: DateTime(2026, 9, 7),
        workingWeekdays: {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        },
        attendanceDates: punched,
        holidays: const [],
      );

      expect(classified.map((day) => day.type), [
        DayCardType.worked,
        DayCardType.worked,
        DayCardType.worked,
        DayCardType.worked,
        DayCardType.worked,
        DayCardType.weekend,
        DayCardType.weekend,
      ]);
    });
  });

  group('Attendance history: full week without punching', () {
    test('Mon–Fri absent, Sat–Sun grouped as weekend, no check-in times', () {
      // August 2026 is fully in the past so the mapper includes the whole week.
      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 8, 1),
        history: const [],
      );

      AttendanceDayRecord on(int day) => month.records.firstWhere(
            (record) =>
                record.date.year == 2026 &&
                record.date.month == 8 &&
                record.date.day == day,
          );

      // Week of Mon 10 Aug → Sun 16 Aug 2026.
      for (final day in [10, 11, 12, 13, 14]) {
        expect(on(day).status, AttendanceDayStatus.absent, reason: 'day $day');
        expect(on(day).checkIn, isNull);
        expect(on(day).checkOut, isNull);
      }

      // Unpunched Sat+Sun collapse into one weekend card dated Sunday.
      expect(on(16).status, AttendanceDayStatus.weekend);
      expect(on(16).checkIn, isNull);
      expect(on(16).checkOut, isNull);
      expect(on(16).weekendLabel, 'Weekend, 15 Aug 2026 - 16 Aug 2026');
      expect(
        month.records.any(
          (record) =>
              record.date.year == 2026 &&
              record.date.month == 8 &&
              record.date.day == 15,
        ),
        isFalse,
      );
    });
  });

  group('Attendance history: full week with punching', () {
    test('every punched day including weekend shows check-in and check-out', () {
      final history = [
        for (var day = 10; day <= 16; day++)
          ManagerEmployeeAttendanceDay(
            date: DateTime(2026, 8, day),
            checkin: '09:00:00',
            checkout: '18:00:00',
          ),
      ];

      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 8, 1),
        history: history,
      );

      for (var day = 10; day <= 16; day++) {
        final record = month.records.firstWhere(
          (item) => item.date.year == 2026 &&
              item.date.month == 8 &&
              item.date.day == day,
        );
        expect(record.status, AttendanceDayStatus.normal, reason: 'day $day');
        expect(record.checkIn, '09:00 AM', reason: 'day $day');
        expect(record.checkOut, '06:00 PM', reason: 'day $day');
      }
    });
  });
}
