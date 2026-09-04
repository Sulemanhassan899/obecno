import 'package:obecno/demo/demo_list.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/attendance_duration.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/attendance_month_bounds.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_history_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/manager_attendance_filters.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/pending_attendance_overlay.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/repositories/manager_attendance_repository.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_attendance_stats.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/date_picker.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/monthly_picker.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatusFilterOption', () {
    test('does not treat Late check in and Late as the same selected row', () {
      expect(StatusFilterOption.isSelected('late_check_in', 'late'), isFalse);
      expect(StatusFilterOption.isSelected('late', 'late_check_in'), isFalse);
      expect(
        StatusFilterOption.isSelected('late_check_in', 'late_check_in'),
        isTrue,
      );
      expect(StatusFilterOption.isSelected('late', 'late'), isTrue);
    });
  });

  group('ManagerAttendanceFilters', () {
    test('maps status labels', () {
      expect(
        ManagerAttendanceFilters.statusDisplayLabel('working'),
        'Active / Working',
      );
      expect(
        ManagerAttendanceFilters.statusDisplayLabel('late'),
        'Late Check-in',
      );
      expect(ManagerAttendanceFilters.statusDisplayLabel('leave'), 'On Leaves');
    });

    test('filters by status', () {
      final late = ManagerAttendanceFilters.apply(
        source: dummyManagerAttendance,
        selectedStatus: 'Late Check-in',
      );
      expect(late, isNotEmpty);
      expect(
        late.every(
          (e) =>
              ManagerAttendanceFilters.statusDisplayLabel(e.status) ==
              'Late Check-in',
        ),
        isTrue,
      );
    });

    test('filters by search query', () {
      final found = ManagerAttendanceFilters.apply(
        source: dummyManagerAttendance,
        searchQuery: 'Armando',
      );
      expect(found, isNotEmpty);
      expect(found.first.name.toLowerCase(), contains('armando'));
    });

    test('filters live items by active / break / location', () {
      const items = [
        ManagerTeamAttendanceItem(
          employeeName: 'Ava',
          checkin: '09:02:00',
          isOpen: true,
          locationId: '1',
          locationName: 'Head Office',
        ),
        ManagerTeamAttendanceItem(
          employeeName: 'Jonas',
          checkin: '09:10:00',
          isOpen: true,
          isOnBreak: true,
          locationId: '2',
          locationName: 'North Office',
        ),
        ManagerTeamAttendanceItem(employeeName: 'Shea'),
      ];

      final active = ManagerAttendanceFilters.applyItems(
        source: items,
        selectedStatus: 'Active',
      );
      expect(active.length, 1);
      expect(active.first.employeeName, 'Ava');

      final onBreak = ManagerAttendanceFilters.applyItems(
        source: items,
        selectedStatus: 'On Break',
      );
      expect(onBreak.length, 1);
      expect(onBreak.first.employeeName, 'Jonas');

      final north = ManagerAttendanceFilters.applyItems(
        source: items,
        selectedLocation: '2',
        locationName: 'North Office',
      );
      expect(north.length, 1);
      expect(north.first.employeeName, 'Jonas');
    });

    test('filters by assigned location members then status', () {
      const items = [
        ManagerTeamAttendanceItem(
          userId: 1,
          employeeName: 'Owner',
          locationId: 'other',
        ),
        ManagerTeamAttendanceItem(
          userId: 2,
          employeeName: 'Manager 1',
          locationId: 'other',
        ),
        ManagerTeamAttendanceItem(
          userId: 3,
          employeeName: 'Employee1',
          checkin: '09:00:00',
          isOpen: true,
          locationId: 'other',
        ),
        ManagerTeamAttendanceItem(
          userId: 4,
          employeeName: 'Employee2',
          locationId: 'bhara',
        ),
      ];
      const members = [
        ManagerEmployeeModel(
          id: '1',
          name: 'Owner',
          role: 'Owner',
          locationIds: ['bhara'],
        ),
        ManagerEmployeeModel(
          id: '2',
          name: 'Manager 1',
          role: 'Manager',
          locationIds: ['bhara'],
        ),
        ManagerEmployeeModel(
          id: '3',
          name: 'Employee1',
          role: 'Employee',
          locationIds: ['bhara'],
        ),
        ManagerEmployeeModel(
          id: '4',
          name: 'Employee2',
          role: 'Employee',
          locationId: 'elsewhere',
        ),
      ];

      final locationOnly = ManagerAttendanceFilters.applyItems(
        source: items,
        selectedLocation: 'bhara',
        locationName: 'bhara khou house',
        members: members,
      );
      expect(locationOnly.map((e) => e.employeeName), [
        'Owner',
        'Manager 1',
        'Employee1',
      ]);

      final absentAtLocation = ManagerAttendanceFilters.applyItems(
        source: items,
        selectedLocation: 'bhara',
        locationName: 'bhara khou house',
        selectedStatus: 'Absent',
        members: members,
      );
      expect(absentAtLocation.map((e) => e.employeeName), [
        'Owner',
        'Manager 1',
      ]);
    });
  });

  group('TeamAttendanceMapper', () {
    test('formats times and maps active status', () {
      const item = ManagerTeamAttendanceItem(
        employeeName: 'Ava',
        checkin: '09:02:00',
        checkout: '17:07:00',
        isOpen: true,
        locationName: 'Head Office',
      );
      final tile = TeamAttendanceMapper.toTile(item);
      expect(tile.checkIn, '09:02 AM');
      expect(tile.checkOut, isNull);
      expect(tile.status, 'working');
      expect(tile.team, 'Head Office');
    });

    test('keeps checkout on a closed shift', () {
      const item = ManagerTeamAttendanceItem(
        employeeName: 'Ava',
        checkin: '09:02:00',
        checkout: '17:07:00',
      );
      final tile = TeamAttendanceMapper.toTile(item);
      expect(tile.checkIn, '09:02 AM');
      expect(tile.checkOut, '05:07 PM');
      expect(tile.status, isEmpty);
    });

    test('leaves employees without punch data as empty status', () {
      const item = ManagerTeamAttendanceItem(employeeName: 'Shea');
      final tile = TeamAttendanceMapper.toTile(item);
      expect(tile.status, isEmpty);
      expect(tile.checkIn, isNull);
      expect(tile.checkOut, isNull);
    });

    test('merges team members so everyone appears by default', () {
      const attendance = [
        ManagerTeamAttendanceItem(
          userId: 31,
          employeeName: 'Employee3',
          checkin: '11:33:44',
          isOpen: true,
        ),
      ];
      const members = [
        ManagerEmployeeModel(id: '10', name: 'Javier Escher', role: 'Sales'),
        ManagerEmployeeModel(id: '31', name: 'Employee3', role: 'Sales'),
        ManagerEmployeeModel(id: '44', name: 'Ava Cole', role: 'Design'),
      ];

      final merged = TeamAttendanceMapper.mergeWithMembers(
        attendance: attendance,
        members: members,
      );
      expect(merged.length, 3);
      expect(merged.map((e) => e.employeeName), [
        'Employee3',
        'Javier Escher',
        'Ava Cole',
      ]);
      expect(merged.first.checkin, '11:33:44');
      expect(TeamAttendanceMapper.uiStatus(merged.first), 'working');
      expect(TeamAttendanceMapper.uiStatus(merged[1]), isEmpty);
    });

    test('location merge keeps only assigned members', () {
      const attendance = [
        ManagerTeamAttendanceItem(
          userId: 31,
          employeeName: 'Employee3',
          checkin: '11:33:44',
          isOpen: true,
        ),
        ManagerTeamAttendanceItem(
          userId: 99,
          employeeName: 'Other Site',
          checkin: '09:00:00',
          isOpen: true,
        ),
      ];
      const members = [
        ManagerEmployeeModel(id: '10', name: 'Javier Escher', role: 'Sales'),
        ManagerEmployeeModel(id: '31', name: 'Employee3', role: 'Sales'),
      ];

      final merged = TeamAttendanceMapper.mergeWithMembers(
        attendance: attendance,
        members: members,
        includeUnmatchedAttendance: false,
      );
      expect(merged.length, 2);
      expect(merged.map((e) => e.employeeName), ['Employee3', 'Javier Escher']);
      expect(merged.any((e) => e.employeeName == 'Other Site'), isFalse);
    });

    test('puts people with a status above empty-state rows', () {
      const items = [
        ManagerTeamAttendanceItem(employeeName: 'Employee1'),
        ManagerTeamAttendanceItem(
          employeeName: 'Employee3',
          checkin: '11:33:44',
          isLate: true,
        ),
        ManagerTeamAttendanceItem(employeeName: 'Manager 1'),
        ManagerTeamAttendanceItem(
          employeeName: 'Jonas',
          checkin: '09:10:00',
          isOpen: true,
          isOnBreak: true,
        ),
      ];

      expect(
        TeamAttendanceMapper.statusFirst(items).map((e) => e.employeeName),
        ['Employee3', 'Jonas', 'Employee1', 'Manager 1'],
      );
    });
  });

  group('EmployeeAttendanceMapper', () {
    test('maps API history details instead of demo timeline', () {
      final data = ManagerEmployeeAttendanceData.fromJson({
        'employee': {
          'id': 31,
          'name': 'Employee3',
          'profile_picture': 'https://cdn.example.com/employee3.jpg',
        },
        'date_from': '2026-08-24',
        'date_to': '2026-08-30',
        'history': [
          {
            'id': 163,
            'date': '2026-08-24',
            'checkin': '11:33:44',
            'checkout': '',
            'hours_worked': '',
            'is_open': true,
            'attendance_details': [
              {
                'type': 'check in',
                'attendance_time': '11:33:44',
                'occurred_at_iso': '2026-08-24T11:33:44+05:00',
                'current_location': '33.7373416,73.1715552',
                'lat': 33.7373416,
                'lon': 73.1715552,
              },
              {
                'type': 'break out',
                'attendance_time': '11:35:25',
                'occurred_at_iso': '2026-08-24T11:35:25+05:00',
                'lat': 33.7373401,
                'lon': 73.1715564,
              },
              {
                'type': 'break in',
                'attendance_time': '11:35:33',
                'occurred_at_iso': '2026-08-24T11:35:33+05:00',
                'lat': 33.737345,
                'lon': 73.1715665,
              },
            ],
          },
        ],
        'hours_totals': {'actual_minutes': 0, 'actual_hours': '00:00:00'},
      });

      final details = EmployeeAttendanceMapper.toDetails(
        data: data,
        day: DateTime(2026, 8, 24),
        fallbackRole: 'Sales',
      );

      expect(details.name, 'Employee3');
      expect(details.checkIn, '11:33 AM');
      expect(details.checkOut, isNull);
      expect(details.durationLabel, '0h 00m');
      expect(details.timeline.length, 3);
      expect(details.timeline.map((e) => e.type).toList(), [
        ManagerAttendanceEventType.breakEnd,
        ManagerAttendanceEventType.breakStart,
        ManagerAttendanceEventType.checkIn,
      ]);
      expect(details.timeline.map((e) => e.timeLabel).toList(), [
        '11:35 AM',
        '11:35 AM',
        '11:33 AM',
      ]);
      expect(details.checkInLat, 33.7373416);
      expect(details.checkInLon, 73.1715552);
      expect(details.attendanceId, 163);
      expect(details.userId, 31);
      expect(details.photo, 'https://cdn.example.com/employee3.jpg');
      expect(
        details.timeline.any((e) => e.timeLabel.contains('01:00')),
        isFalse,
      );
      expect(
        details.timeline.any((e) => e.timeLabel.contains('02:00')),
        isFalse,
      );
    });

    test('detects an open break from the last attendance event', () {
      final openBreak = ManagerEmployeeAttendanceDay(
        date: DateTime(2026, 8, 24),
        checkin: '11:33:44',
        isOpen: true,
        details: const [
          ManagerEmployeeAttendanceDetail(
            type: 'check in',
            attendanceTime: '11:33:44',
          ),
          ManagerEmployeeAttendanceDetail(
            type: 'break out',
            attendanceTime: '11:35:25',
          ),
        ],
      );
      final closedBreak = ManagerEmployeeAttendanceDay(
        date: DateTime(2026, 8, 24),
        checkin: '11:33:44',
        isOpen: true,
        details: const [
          ManagerEmployeeAttendanceDetail(
            type: 'check in',
            attendanceTime: '11:33:44',
          ),
          ManagerEmployeeAttendanceDetail(
            type: 'break out',
            attendanceTime: '11:35:25',
          ),
          ManagerEmployeeAttendanceDetail(
            type: 'break in',
            attendanceTime: '11:35:33',
          ),
        ],
      );

      expect(EmployeeAttendanceMapper.isOnBreak(openBreak), isTrue);
      expect(EmployeeAttendanceMapper.isOnBreak(closedBreak), isFalse);
    });

    test('treats a later check-in as working even after a checkout', () {
      final day = ManagerEmployeeAttendanceDay(
        date: DateTime(2026, 9, 2),
        checkin: '12:00:00',
        checkout: '22:51:00',
        isOpen: false,
        details: const [
          ManagerEmployeeAttendanceDetail(
            type: 'check in',
            attendanceTime: '12:00:00',
          ),
          ManagerEmployeeAttendanceDetail(
            type: 'break in',
            attendanceTime: '22:51:00',
          ),
          ManagerEmployeeAttendanceDetail(
            type: 'check out',
            attendanceTime: '22:51:00',
          ),
          ManagerEmployeeAttendanceDetail(
            type: 'check in',
            attendanceTime: '22:56:00',
          ),
        ],
      );

      expect(EmployeeAttendanceMapper.isSessionOpen(day), isTrue);
      expect(EmployeeAttendanceMapper.isOnBreak(day), isFalse);
      expect(EmployeeAttendanceMapper.liveCheckOut(day), isNull);
      expect(EmployeeAttendanceMapper.firstCheckIn(day), '12:00:00');
    });

    test('keeps list photo and attendance id when day payload omits them', () {
      final data = ManagerEmployeeAttendanceData.fromJson({
        'employee': {'id': 31, 'name': 'Employee3'},
        'history': [
          {
            'date': '2026-08-24',
            'attendance': {'attendance_id': 163, 'checkin': '11:33:44'},
            'attendance_details': const [],
          },
        ],
      });

      final details = EmployeeAttendanceMapper.toDetails(
        data: data,
        day: DateTime(2026, 8, 24),
        fallbackName: 'Employee3',
        fallbackRole: 'Sales',
        fallbackPhoto: 'https://cdn.example.com/from-team.jpg',
        fallbackAttendanceId: 999,
      );

      expect(details.photo, 'https://cdn.example.com/from-team.jpg');
      expect(details.attendanceId, 163);
    });
  });

  group('ManagerAttendanceRepository.editSaveBody', () {
    test('sends date and attendance_id and omits empty checkout', () {
      final body = ManagerAttendanceRepository.editSaveBody(
        attendanceId: 163,
        userId: 31,
        date: '2026-08-24',
        deviceDetails: 'iPhone',
        lat: 33.73,
        lon: 73.17,
        checkIn: '11:30:00',
        checkOut: null,
        breakStart: '11:35:00',
        breakEnd: '11:36:00',
        changes: const [],
      );

      expect(body['id'], 163);
      expect(body['attendance_id'], 163);
      expect(body['user_id'], 31);
      expect(body['date'], '2026-08-24');
      expect(body['checkin'], '11:30:00');
      expect(body.containsKey('checkout'), isFalse);
      expect(body['breakout'], '11:35:00');
      expect(body['breakin'], '11:36:00');
    });
  });

  group('ManagerAttendanceRepository.employeeAttendanceSaveBody', () {
    test('includes check times and events for create/edit', () {
      final body = ManagerAttendanceRepository.employeeAttendanceSaveBody(
        attendanceId: null,
        date: '2026-08-26',
        deviceDetails: 'iPhone',
        lat: 33.73,
        lon: 73.17,
        checkIn: '09:00:00',
        checkOut: '18:00:00',
        breakStart: '10:00:00',
        breakEnd: '10:30:00',
        changes: const [],
      );

      expect(body['date'], '2026-08-26');
      expect(body.containsKey('attendance_id'), isFalse);
      expect(body['check_in'], '09:00:00');
      expect(body['check_out'], '18:00:00');
      expect(body['events'], isA<List>());
      expect((body['events'] as List).length, 4);
    });

    test('attaches existing punch ids so an edit updates that event', () {
      final body = ManagerAttendanceRepository.employeeAttendanceSaveBody(
        attendanceId: 901,
        userId: 12,
        date: '2026-08-28',
        deviceDetails: 'iPhone',
        lat: 33.73,
        lon: 73.17,
        checkIn: '09:00:00',
        checkInDetailId: '1001',
        changes: const [],
      );

      expect(body['attendance_id'], 901);
      expect(body['check_in'], '09:00:00');
      expect(body.containsKey('check_out'), isFalse);
      final events = body['events'] as List;
      expect(events, [
        {'type': 'checkin', 'time': '09:00:00', 'id': 1001},
      ]);
    });
  });

  group('ManagerEmployeeHistoryMapper', () {
    test(
      'shows punched times without seconds and fills leave/weekend days',
      () {
        final month = ManagerEmployeeHistoryMapper.build(
          month: DateTime(2026, 7, 1),
          history: [
            ManagerEmployeeAttendanceDay(
              date: DateTime(2026, 7, 1),
              checkin: '09:00:33',
              checkout: '17:05:12',
            ),
          ],
          scheduledCheckIn: const TimeOfDay(hour: 9, minute: 0),
          graceMinutes: 0,
          scheduledCheckOut: const TimeOfDay(hour: 17, minute: 0),
        );

        final worked = month.records.firstWhere(
          (record) => record.date.day == 1,
        );
        expect(worked.checkIn, '09:00 AM');
        expect(worked.checkOut, '05:05 PM');
        expect(month.summary.workingDays, 1);
        expect(month.summary.absentOrLeaves, greaterThan(0));
        expect(
          month.records.any((e) => e.status == AttendanceDayStatus.weekend),
          isTrue,
        );
        expect(
          month.records.any((e) => e.status == AttendanceDayStatus.absent),
          isTrue,
        );
        expect(
          month.records.any((e) => e.status == AttendanceDayStatus.onLeave),
          isFalse,
        );
      },
    );

    test('does not show days before the employee joining date', () {
      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 7, 1),
        history: [
          ManagerEmployeeAttendanceDay(
            date: DateTime(2026, 7, 1),
            checkin: '09:00:00',
            checkout: '17:00:00',
          ),
          ManagerEmployeeAttendanceDay(
            date: DateTime(2026, 7, 6),
            checkin: '09:00:00',
            checkout: '17:00:00',
          ),
        ],
        joiningDate: DateTime(2026, 7, 5),
      );

      expect(month.records.any((record) => record.date.day < 5), isFalse);
      expect(month.records.any((record) => record.date.day == 6), isTrue);
    });
  });

  group('ManagerEmployeePolicy', () {
    test('parses check-in times and grace minutes', () {
      expect(
        ManagerEmployeePolicy.parseTime('08:00 AM'),
        const TimeOfDay(hour: 8, minute: 0),
      );
      expect(ManagerEmployeePolicy.parseMinutes('15 mins'), 15);
      expect(
        const ManagerEmployeePolicy(breakTime: '60').breakLabel,
        '60:00 mins',
      );
    });
  });

  group('ManagerEmployeeModel', () {
    test('reads account and location fields from profile json', () {
      final employee = ManagerEmployeeModel.fromJson({
        'id': 31,
        'name': 'Employee3',
        'email': 'emp3@obecno.com',
        'phone': '5551234',
        'employee_code': 'EMP-31',
        'address': 'Al Wasl Road, Dubai',
        'default_location_id': '12',
        'location_ids': ['12', '15'],
        'location_name': 'Head Office',
        'created_by': {'name': 'Ava Montgomery'},
        'created_at': '2026-01-20',
      });

      expect(employee.userId, 31);
      expect(employee.email, 'emp3@obecno.com');
      expect(employee.employeeCode, 'EMP-31');
      expect(employee.locationId, '12');
      expect(employee.locationIds, ['12', '15']);
      expect(employee.createdBy, 'Ava Montgomery');
    });

    test('parses joining_date as a date-only calendar day', () {
      final employee = ManagerEmployeeModel.fromJson({
        'id': 12,
        'name': 'Employee1',
        'joining_date': '2026-07-05',
      });
      expect(employee.joiningDate, DateTime(2026, 7, 5));
    });

    test('falls back to created_at when joining_date is missing', () {
      final employee = ManagerEmployeeModel.fromJson({
        'id': 12,
        'name': 'Employee1',
        'created_at': '2026-07-05',
      });
      expect(employee.joiningDate, DateTime(2026, 7, 5));
    });
  });

  group('AttendanceMonthBounds', () {
    test('blocks previous month before the joining month', () {
      final join = DateTime(2026, 7, 5);
      final now = DateTime(2026, 8, 31);

      expect(
        AttendanceMonthBounds.canGoPrevious(
          selectedMonth: DateTime(2026, 7),
          joiningDate: join,
        ),
        isFalse,
      );
      expect(
        AttendanceMonthBounds.canGoPrevious(
          selectedMonth: DateTime(2026, 8),
          joiningDate: join,
        ),
        isTrue,
      );
      expect(
        AttendanceMonthBounds.clampMonth(
          selectedMonth: DateTime(2026, 6),
          joiningDate: join,
          now: now,
        ),
        DateTime(2026, 7),
      );
      expect(AttendanceMonthBounds.minimumMonth(join), DateTime(2026, 7));
    });
  });

  group('MonthYearContent joining bounds', () {
    testWidgets('hides months and years before the joining date', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthYearContent(
              initialDate: DateTime(2026, 8, 1),
              minDate: DateTime(2026, 7, 5),
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('January'), findsNothing);
      expect(find.text('March'), findsNothing);
      expect(find.text('June'), findsNothing);
      expect(find.text('July'), findsOneWidget);
      expect(find.text('August'), findsOneWidget);
      expect(find.text('2024'), findsNothing);
      expect(find.text('2025'), findsNothing);
      expect(find.text('2026'), findsOneWidget);
    });
  });

  group('DateMonthYearContent calendar', () {
    testWidgets('shows a calendar grid instead of a wheel', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateMonthYearContent(initialDate: now, onSelected: (_) {}),
          ),
        ),
      );

      expect(find.text('Select Date'), findsOneWidget);
      expect(find.byType(ListWheelScrollView), findsNothing);
      expect(find.text('${now.day}'), findsWidgets);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('tapping the month title opens a month and year picker', (
      tester,
    ) async {
      final now = DateTime.now();
      final title =
          '${DateMonthYearContentState.months[now.month - 1]} ${now.year}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateMonthYearContent(initialDate: now, onSelected: (_) {}),
          ),
        ),
      );

      await tester.tap(find.text(title));
      await tester.pumpAndSettle();

      expect(find.text('Select Month & Year'), findsOneWidget);
      expect(find.byType(ListWheelScrollView), findsWidgets);
    });
  });

  group('AttendanceDuration', () {
    test('uses checkout minus check-in for a closed shift', () {
      expect(
        AttendanceDuration.label(
          day: DateTime(2026, 8, 28),
          checkIn: '10:50 AM',
          checkOut: '12:20 PM',
        ),
        '1h 30m',
      );
    });

    test('uses elapsed time for an open shift on the same day', () {
      expect(
        AttendanceDuration.label(
          day: DateTime(2026, 8, 28),
          checkIn: '10:50 AM',
          now: DateTime(2026, 8, 28, 12, 20),
        ),
        '1h 30m',
      );
    });
  });

  group('ManagerTeamAttendanceItem', () {
    test('reads check_in aliases used by some team-attendance payloads', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 1,
        'employee_name': 'Owner',
        'check_in': '10:50:00',
        'is_open': true,
      });
      expect(item.hasCheckIn, isTrue);
      expect(item.checkin, '10:50:00');
    });

    test('maps live status to working, on break, and on leave', () {
      expect(
        TeamAttendanceMapper.uiStatus(
          const ManagerTeamAttendanceItem(
            employeeName: 'Owner',
            checkin: '12:00:00',
            isOpen: true,
          ),
        ),
        'working',
      );
      expect(
        TeamAttendanceMapper.uiStatus(
          const ManagerTeamAttendanceItem(
            employeeName: 'Owner',
            checkin: '12:00:00',
            breakout: '09:25:00',
            isOpen: true,
          ),
        ),
        'break',
      );
      expect(
        TeamAttendanceMapper.uiStatus(
          const ManagerTeamAttendanceItem(
            employeeName: 'Owner',
            status: 'on_leave',
          ),
        ),
        'leave',
      );
    });

    test('treats an open breakout as on break even without is_on_break', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 1,
        'employee_name': 'Owner',
        'check_in': '12:00:00',
        'breakout': '09:25:00',
        'is_open': true,
        'live_status': 'working',
      });
      expect(item.isCurrentlyOnBreak, isTrue);
      expect(item.isActive, isFalse);
      expect(TeamAttendanceMapper.uiStatus(item), 'break');
    });

    test('treats live_status on_break as on break', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 1,
        'employee_name': 'Owner',
        'check_in': '12:00:00',
        'live_status': 'on_break',
      });
      expect(item.isCurrentlyOnBreak, isTrue);
      expect(TeamAttendanceMapper.uiStatus(item), 'break');
    });

    test('treats live_status late as a late check-in', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 3,
        'employee_name': 'Employee1',
        'check_in_time': '10:50:00',
        'live_status': 'late',
      });
      expect(item.hasCheckIn, isTrue);
      expect(item.isLate, isTrue);
      expect(item.checkin, '10:50:00');

      final filtered = ManagerAttendanceFilters.applyItems(
        source: [item],
        selectedStatus: 'Late Check-in',
      );
      expect(filtered, hasLength(1));
      expect(filtered.first.employeeName, 'Employee1');
    });
  });

  group('ManagerEmployeeHistoryMapper punches', () {
    test('keeps a punched weekday even if it would otherwise be leave', () {
      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 8, 1),
        history: [
          ManagerEmployeeAttendanceDay(
            date: DateTime(2026, 8, 28),
            checkin: '10:50:00',
            isOpen: true,
          ),
        ],
      );

      final day = month.records.firstWhere((record) => record.date.day == 28);
      expect(day.status, isNot(AttendanceDayStatus.onLeave));
      expect(day.status, isNot(AttendanceDayStatus.absent));
      expect(day.checkIn, '10:50 AM');
    });

    test('keeps holiday cards instead of grouping them into weekends', () {
      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 8, 1),
        history: const [],
        holidays: [
          HolidayInfo(date: DateTime(2026, 8, 14), name: 'National Day'),
        ],
      );

      final holiday = month.records.firstWhere(
        (record) => record.date.day == 14,
      );
      expect(holiday.status, AttendanceDayStatus.holiday);
      expect(holiday.weekendLabel, 'National Day');
      expect(
        month.records.where((e) => e.status == AttendanceDayStatus.holiday),
        hasLength(1),
      );
    });

    test('marks unworked weekdays as absent, not on leave', () {
      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 8, 1),
        history: const [],
      );

      final friday = month.records.firstWhere(
        (record) => record.date.day == 28,
      );
      expect(friday.status, AttendanceDayStatus.absent);
      expect(friday.checkIn, isNull);
      expect(friday.checkOut, isNull);
    });

    test('uses is_holiday from history when the holidays list is empty', () {
      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 8, 1),
        history: [
          ManagerEmployeeAttendanceDay(
            date: DateTime(2026, 8, 14),
            isHoliday: true,
            holidayName: 'National Day',
          ),
        ],
      );

      final holiday = month.records.firstWhere(
        (record) => record.date.day == 14,
      );
      expect(holiday.status, AttendanceDayStatus.holiday);
      expect(holiday.weekendLabel, 'National Day');
    });
  });

  group('LocationAttendanceStats', () {
    test('counts present as punched people over assigned total', () {
      const location = ManagerLocationModel(
        id: '12',
        name: 'i-10 cowork',
        address: 'Islamabad',
      );
      const attendance = [
        ManagerTeamAttendanceItem(
          userId: 3,
          employeeName: 'Employee3',
          checkin: '10:37:00',
          isLate: true,
          isOpen: true,
          locationId: '12',
        ),
        ManagerTeamAttendanceItem(
          userId: 1,
          employeeName: 'Owner',
          checkin: '10:50:00',
          isOpen: true,
          locationId: '12',
        ),
      ];
      const members = [
        ManagerEmployeeModel(
          id: '1',
          name: 'Owner',
          role: 'Owner',
          locationId: '12',
        ),
        ManagerEmployeeModel(
          id: '3',
          name: 'Employee3',
          role: 'Sales',
          locationId: '12',
        ),
      ];

      final stats = LocationAttendanceStats.of(
        location: location,
        attendance: attendance,
        members: members,
      );
      expect(stats.active, 2);
      expect(stats.total, 2);
      expect(stats.lateCheckIns, 1);
    });

    test('includes an owner punch even when assignment lists omit them', () {
      const location = ManagerLocationModel(
        id: '12',
        name: 'i-10 cowork',
        address: 'Islamabad',
      );
      const attendance = [
        ManagerTeamAttendanceItem(
          userId: 3,
          employeeName: 'Employee3',
          checkin: '10:37:00',
          isLate: true,
          locationId: '12',
        ),
        ManagerTeamAttendanceItem(
          userId: 1,
          employeeName: 'Owner',
          checkin: '10:50:00',
          locationId: '12',
        ),
      ];
      const members = [
        ManagerEmployeeModel(
          id: '3',
          name: 'Employee3',
          role: 'Sales',
          locationId: '12',
        ),
      ];

      final stats = LocationAttendanceStats.of(
        location: location,
        attendance: attendance,
        members: members,
      );
      expect(stats.active, 2);
      expect(stats.total, 2);
    });

    test(
      'matches an owner punch by office name when location_id is missing',
      () {
        const location = ManagerLocationModel(
          id: '12',
          name: 'i-10 cowork',
          address: 'Islamabad',
        );
        const attendance = [
          ManagerTeamAttendanceItem(
            userId: 3,
            employeeName: 'Employee3',
            checkin: '10:37:00',
            locationId: '12',
          ),
          ManagerTeamAttendanceItem(
            userId: 1,
            employeeName: 'Owner',
            checkin: '10:50:00',
            currentLocation: 'i-10 cowork',
          ),
        ];
        const members = [
          ManagerEmployeeModel(
            id: '3',
            name: 'Employee3',
            role: 'Sales',
            locationId: '12',
          ),
        ];

        final stats = LocationAttendanceStats.of(
          location: location,
          attendance: attendance,
          members: members,
        );
        expect(stats.active, 2);
      },
    );

    test('counts an untagged owner punch on the only office', () {
      const location = ManagerLocationModel(
        id: '12',
        name: 'i-10 cowork',
        address: 'Islamabad',
      );
      const attendance = [
        ManagerTeamAttendanceItem(
          userId: 3,
          employeeName: 'Employee3',
          checkin: '10:37:00',
          locationId: '12',
        ),
        ManagerTeamAttendanceItem(
          userId: 1,
          employeeName: 'Owner',
          checkin: '10:50:00',
        ),
      ];
      const members = [
        ManagerEmployeeModel(
          id: '3',
          name: 'Employee3',
          role: 'Sales',
          locationId: '12',
        ),
      ];

      final stamped = LocationAttendanceStats.stamp(
        locations: [location],
        attendance: attendance,
        members: members,
      );
      expect(stamped.single.present, 2);
    });
  });

  group('OverviewSummary', () {
    test('counts the owner check-in in present today', () {
      const attendance = [
        ManagerTeamAttendanceItem(
          userId: 3,
          employeeName: 'Employee3',
          checkin: '10:37:00',
        ),
        ManagerTeamAttendanceItem(
          userId: 2,
          employeeName: 'Employee2',
          checkin: '09:10:00',
        ),
        ManagerTeamAttendanceItem(
          userId: 1,
          employeeName: 'Owner',
          checkin: '10:50:00',
        ),
        ManagerTeamAttendanceItem(userId: 4, employeeName: 'Employee4'),
        ManagerTeamAttendanceItem(userId: 5, employeeName: 'Employee5'),
        ManagerTeamAttendanceItem(userId: 6, employeeName: 'Employee6'),
        ManagerTeamAttendanceItem(userId: 7, employeeName: 'Employee7'),
      ];

      final summary = OverviewSummary.fromAttendance(
        attendance: attendance,
        teamMemberCount: 7,
      );
      expect(summary.presentToday, 3);
      expect(summary.totalTeamMembers, 7);
    });
  });

  group('ManagerAttendanceDetailsData', () {
    test('keeps saved times when a stale reload still has the old punches', () {
      final stale = ManagerAttendanceDetailsData(
        day: DateTime(2026, 8, 28),
        name: 'Employee1',
        checkIn: '11:27 AM',
        durationLabel: '4h 48m',
        timeline: const [
          ManagerAttendanceTimelineEvent(
            type: ManagerAttendanceEventType.checkIn,
            timeLabel: '11:27 AM',
          ),
        ],
      );

      final updated = stale.withSavedTimes(
        const AddAttendanceSaveResult(checkIn: TimeOfDay(hour: 9, minute: 27)),
      );

      expect(updated.checkIn, '09:27 AM');
      expect(updated.checkOut, isNull);
      expect(
        updated.timeline.any(
          (e) => e.type == ManagerAttendanceEventType.breakStart,
        ),
        isFalse,
      );
      expect(
        updated.timeline.any(
          (e) => e.type == ManagerAttendanceEventType.checkOut,
        ),
        isFalse,
      );
    });
  });

  group('PendingAttendanceOverlay', () {
    test(
      'keeps employee 1 times after employee 3 is saved and list reloads',
      () {
        final day = DateTime(2026, 8, 28);
        final apiItems = [
          ManagerTeamAttendanceItem(
            userId: 1,
            employeeName: 'Employee1',
            checkin: '11:27:00',
            isOpen: true,
            isLate: true,
          ),
          ManagerTeamAttendanceItem(
            userId: 3,
            employeeName: 'Employee3',
            checkin: '09:00:00',
            isOpen: true,
            isLate: true,
          ),
        ];

        final pending = [
          PendingAttendanceSave(
            userId: 1,
            employeeName: 'Employee1',
            day: day,
            checkIn: '09:27:00',
            checkOut: '18:00:00',
          ),
          PendingAttendanceSave(
            userId: 3,
            employeeName: 'Employee3',
            day: day,
            checkIn: '08:37:00',
            checkOut: '18:00:00',
          ),
        ];

        final overlaid = PendingAttendanceOverlay.apply(
          items: apiItems,
          pending: pending,
          selectedDate: day,
        );

        final employee1 = overlaid.firstWhere((e) => e.userId == 1);
        final employee3 = overlaid.firstWhere((e) => e.userId == 3);

        expect(employee1.checkin, '09:27:00');
        expect(employee1.checkout, '18:00:00');
        expect(employee1.isLate, isFalse);
        expect(employee3.checkin, '08:37:00');
        expect(employee3.checkout, '18:00:00');
      },
    );

    test('matches by name when the list row has no user id', () {
      final day = DateTime(2026, 8, 28);
      const apiItems = [
        ManagerTeamAttendanceItem(
          employeeName: 'Employee1',
          checkin: '11:27:00',
          isLate: true,
        ),
      ];

      final overlaid = PendingAttendanceOverlay.apply(
        items: apiItems,
        pending: [
          PendingAttendanceSave(
            userId: 1,
            employeeName: 'Employee1',
            day: day,
            checkIn: '09:27:00',
            checkOut: null,
          ),
        ],
        selectedDate: day,
      );

      expect(overlaid.single.checkin, '09:27:00');
    });

    test('adds a saved day to empty monthly history so it is not on leave', () {
      final day = DateTime(2026, 8, 28);
      final history = PendingAttendanceOverlay.applyToHistory(
        history: const [],
        pending: [
          PendingAttendanceSave(
            userId: 41,
            employeeName: 'Test Employee 1',
            day: day,
            checkIn: '07:00:00',
            checkOut: '18:00:00',
          ),
        ],
        userId: 41,
        employeeName: 'Test Employee 1',
      );

      expect(history, hasLength(1));
      expect(history.single.checkin, '07:00:00');
      expect(history.single.checkout, '18:00:00');

      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 8, 1),
        history: history,
      );
      final friday = month.records.firstWhere(
        (record) => record.date.day == 28,
      );
      expect(friday.status, AttendanceDayStatus.normal);
      expect(friday.checkIn, '07:00 AM');
      expect(friday.checkOut, '06:00 PM');
      expect(month.summary.workingDays, greaterThan(0));
    });
  });
}
