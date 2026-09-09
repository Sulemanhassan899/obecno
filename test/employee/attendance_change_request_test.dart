import 'package:obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/employee_module/attendance/services/scheduled_attendance_times.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceChangeRequestPayload', () {
    test('serializes attendancedetail_id with 12-hour old/new values', () {
      final payload = AttendanceChangeRequestPayload(
        attendanceDetailId: '56',
        oldValue: '9:00 AM',
        newValue: '9:30 AM',
      );

      expect(payload.toJson(), {
        'attendancedetail_id': 56,
        'old_value': '9:00 AM',
        'new_value': '9:30 AM',
      });
    });

    test(
      'sends all four day punches in one POST /employee/attendance/edit body',
      () {
        // Recorded: 11:50 AM in, 1:00 PM break start, 2:00 PM break end, 5:00 PM out.
        // Requested: 10:00 AM in, 12:00 PM break start, 1:00 PM break end, 6:00 PM out.
        final body = AttendanceService.editRequestBody(
          attendanceId: 42,
          deviceDetails: 'Vivo e23 | Android 13.5',
          lat: 33.570435,
          lon: 73.1407564,
          changes: const [
            AttendanceChangeRequestPayload(
              attendanceDetailId: '56',
              oldValue: '11:50 AM',
              newValue: '10:00 AM',
            ),
            AttendanceChangeRequestPayload(
              attendanceDetailId: '57',
              oldValue: '1:00 PM',
              newValue: '12:00 PM',
            ),
            AttendanceChangeRequestPayload(
              attendanceDetailId: '58',
              oldValue: '2:00 PM',
              newValue: '1:00 PM',
            ),
            AttendanceChangeRequestPayload(
              attendanceDetailId: '59',
              oldValue: '5:00 PM',
              newValue: '6:00 PM',
            ),
          ],
        );

        expect(body, {
          'id': 42,
          'device_details': 'Vivo e23 | Android 13.5',
          'lat': 33.570435,
          'lon': 73.1407564,
          'changes': [
            {
              'attendancedetail_id': 56,
              'old_value': '11:50 AM',
              'new_value': '10:00 AM',
            },
            {
              'attendancedetail_id': 57,
              'old_value': '1:00 PM',
              'new_value': '12:00 PM',
            },
            {
              'attendancedetail_id': 58,
              'old_value': '2:00 PM',
              'new_value': '1:00 PM',
            },
            {
              'attendancedetail_id': 59,
              'old_value': '5:00 PM',
              'new_value': '6:00 PM',
            },
          ],
        });
        expect((body['changes'] as List), hasLength(4));
      },
    );

    test('create-day request includes date and clock times', () {
      final body = AttendanceService.editRequestBody(
        attendanceId: null,
        deviceDetails: 'iPhone',
        lat: 33.57,
        lon: 73.14,
        changes: const [],
        date: '2026-09-07',
        checkIn: '08:00:00',
        checkOut: '17:00:00',
      );

      expect(body.containsKey('id'), isFalse);
      expect(body['date'], '2026-09-07');
      expect(body['check_in'], '08:00:00');
      expect(body['check_out'], '17:00:00');
      expect(body['changes'], isEmpty);
    });

    test('create-day change requests omit id and detail ids', () {
      final body = AttendanceService.editRequestBody(
        attendanceId: null,
        deviceDetails: 'iPhone',
        lat: 33.57,
        lon: 73.14,
        date: '2026-09-03',
        checkIn: '09:00:00',
        checkOut: '18:00:00',
        changes: const [
          AttendanceChangeRequestPayload(
            oldValue: '--',
            newValue: '9:00 AM',
            type: 'check in',
          ),
          AttendanceChangeRequestPayload(
            oldValue: '--',
            newValue: '6:00 PM',
            type: 'check out',
          ),
        ],
      );

      expect(body.containsKey('id'), isFalse);
      expect(body['date'], '2026-09-03');
      expect(body['change_requests'], hasLength(2));
      expect(
        (body['changes'] as List).first.containsKey('attendancedetail_id'),
        isFalse,
      );
    });
  });

  group('AttendanceDetailsData', () {
    test('parses attendance id from id when attendance_id is missing', () {
      final data = AttendanceDetailsData.fromJson({
        'user_id': 31,
        'date': '2026-09-03',
        'id': 88,
        'attendance_details': [],
      });
      expect(data.attendanceId, 88);
    });

    test('create-day body has no id and includes clock times', () {
      final body = AttendanceService.createRequestBody(
        date: '2026-09-03',
        deviceDetails: 'iPhone',
        lat: 33.57,
        lon: 73.14,
        checkIn: '09:00:00',
        checkOut: '19:00:00',
        userId: 31,
      );

      expect(body.containsKey('id'), isFalse);
      expect(body['date'], '2026-09-03');
      expect(body['user_id'], 31);
      expect(body['check_in'], '09:00:00');
      expect(body['check_out'], '19:00:00');
      expect(body['events'], [
        {'type': 'checkin', 'time': '09:00:00'},
        {'type': 'checkout', 'time': '19:00:00'},
      ]);
    });

    test('parses detail ids used for fix requests', () {
      final data = AttendanceDetailsData.fromJson({
        'user_id': 31,
        'date': '2026-08-10',
        'attendance_id': 120,
        'total': 1,
        'attendance_details': [
          {
            'id': 434,
            'type': 'check in',
            'occurred_at_iso': '2026-08-10T09:34:52.000Z',
            'change_requests': [],
            'changes': [],
          },
        ],
      });

      expect(data.attendanceId, 120);
      expect(data.details, hasLength(1));
      expect(data.details.first.id, '434');
      expect(data.toHistoryEvents().first.id, '434');
    });

    test(
      'maps approved change card fields and dedupes changes/change_requests',
      () {
        const change = {
          'id': 6,
          'attendancedetail_id': 511,
          'old_value': '08:55:22',
          'old_value_label': '08:55 AM',
          'new_value': '07:55:00',
          'new_value_label': '07:55 AM',
          'status': 'approved',
          'status_label': 'Approved',
          'is_pending': false,
          'is_approved': true,
          'is_rejected': false,
          'updated_id': 22,
          'updated_by_name': 'Naveed Ramzan',
          'created_at': '2026-08-17 12:40:26',
          'updated_at': '2026-08-17 12:40:26',
        };

        final data = AttendanceDetailsData.fromJson({
          'user_id': 24,
          'date': '2026-08-17',
          'attendance_id': 135,
          'total': 1,
          'attendance_details': [
            {
              'id': 511,
              'type': 'check in',
              'occurred_at_iso': '2026-08-17T07:55:00+05:00',
              'changes': [change],
              'change_requests': [change],
            },
          ],
        });

        final requests = data.details.first.editRequests;
        expect(requests, hasLength(1));
        expect(requests.first.status, AttendanceEditRequestStatus.approved);
        expect(requests.first.actionedBy, 'Naveed Ramzan');
        expect(requests.first.originalTime, '08:55 AM');
        expect(requests.first.newTime, '07:55 AM');
      },
    );
  });

  group('ScheduledAttendanceTimes', () {
    test('uses policy check-in, check-out and break duration', () {
      const policy = ManagerEmployeePolicy(
        checkInTime: '09:00 AM',
        checkOutTime: '06:00 PM',
        breakTime: '30 mins',
      );

      final scheduled = ScheduledAttendanceTimes.fromPolicy(policy);

      expect(scheduled.checkIn, const TimeOfDay(hour: 9, minute: 0));
      expect(scheduled.checkOut, const TimeOfDay(hour: 18, minute: 0));
      expect(scheduled.breakEnd.hour * 60 + scheduled.breakEnd.minute,
          scheduled.breakStart.hour * 60 + scheduled.breakStart.minute + 30);
    });
  });
}
