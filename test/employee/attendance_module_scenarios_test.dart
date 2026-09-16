import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_edit_request_store.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

AttendanceDayRecord _overlayPendingAdd(
  AttendanceDayRecord record,
  AttendanceEditRequestStore store,
) {
  return record.overlayPendingAdd(pendingAdd: store.hasPendingAdd(record.date));
}

bool _isClockHms(dynamic value) {
  return RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(value.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AttendanceEditRequestStore.instance.debugReset();
  });

  group('Edit attendance payload (screenshot 4 Sep 2026)', () {
    test('converts the shown 12-hour times into a valid changes array', () {
      final body = AttendanceService.editRequestBody(
        attendanceId: 188,
        deviceDetails: 'iPhone',
        lat: 33.57,
        lon: 73.14,
        date: '2026-09-04',
        changes: const [
          AttendanceChangeRequestPayload(
            attendanceDetailId: '801',
            oldValue: '9:00 AM',
            newValue: '12:00 PM',
            type: 'check in',
          ),
          AttendanceChangeRequestPayload(
            attendanceDetailId: '802',
            oldValue: '10:00 AM',
            newValue: '3:00 PM',
            type: 'break out',
          ),
          AttendanceChangeRequestPayload(
            attendanceDetailId: '803',
            oldValue: '10:30 AM',
            newValue: '4:00 PM',
            type: 'break in',
          ),
          AttendanceChangeRequestPayload(
            attendanceDetailId: '804',
            oldValue: '6:00 PM',
            newValue: '8:00 PM',
            type: 'check out',
          ),
        ],
      );

      expect(body['attendance_id'], 188);
      expect(body['date'], '2026-09-04');
      expect(body['changes'], [
        {
          'attendancedetail_id': 801,
          'old_value': '09:00:00',
          'new_value': '12:00:00',
        },
        {
          'attendancedetail_id': 802,
          'old_value': '10:00:00',
          'new_value': '15:00:00',
        },
        {
          'attendancedetail_id': 803,
          'old_value': '10:30:00',
          'new_value': '16:00:00',
        },
        {
          'attendancedetail_id': 804,
          'old_value': '18:00:00',
          'new_value': '20:00:00',
        },
      ]);
      expect(body['change_requests'], [
        {
          'attendance_detail_id': 801,
          'type': 'check in',
          'original_time': '09:00:00',
          'requested_time': '12:00:00',
        },
        {
          'attendance_detail_id': 802,
          'type': 'break out',
          'original_time': '10:00:00',
          'requested_time': '15:00:00',
        },
        {
          'attendance_detail_id': 803,
          'type': 'break in',
          'original_time': '10:30:00',
          'requested_time': '16:00:00',
        },
        {
          'attendance_detail_id': 804,
          'type': 'check out',
          'original_time': '18:00:00',
          'requested_time': '20:00:00',
        },
      ]);

      for (final row in body['changes'] as List) {
        expect(_isClockHms(row['old_value']), isTrue);
        expect(_isClockHms(row['new_value']), isTrue);
        expect(row['old_value'], isNot('--'));
        expect(row.containsKey('attendancedetail_id'), isTrue);
        expect(row.containsKey('id'), isFalse);
        expect(row.containsKey('type'), isFalse);
      }
    });

    test('12:00 PM stays noon and 12:00 AM stays midnight', () {
      expect(AttendanceChangeRequestPayload.asHms('12:00 PM'), '12:00:00');
      expect(AttendanceChangeRequestPayload.asHms('12:00 AM'), '00:00:00');
      expect(AttendanceChangeRequestPayload.asHms('8:00 PM'), '20:00:00');
      expect(AttendanceChangeRequestPayload.asHms('--'), '00:00:00');
    });

    test(
      'drops break rows without detail ids so the changes array stays valid',
      () {
        final body = AttendanceService.editRequestBody(
          attendanceId: 211,
          deviceDetails: 'iPhone',
          lat: 33.57,
          lon: 73.14,
          date: '2026-09-14',
          changes: const [
            AttendanceChangeRequestPayload(
              attendanceDetailId: '501',
              oldValue: '1:29 AM',
              newValue: '1:29 AM',
              type: 'check in',
            ),
            AttendanceChangeRequestPayload(
              oldValue: '10:00 AM',
              newValue: '7:59 PM',
              type: 'break out',
            ),
            AttendanceChangeRequestPayload(
              oldValue: '10:30 AM',
              newValue: '10:30 AM',
              type: 'break in',
            ),
            AttendanceChangeRequestPayload(
              attendanceDetailId: '504',
              oldValue: '5:00 PM',
              newValue: '8:00 AM',
              type: 'check out',
            ),
          ],
        );

        expect(body['id'], 211);
        expect(body['changes'], [
          {
            'attendancedetail_id': 501,
            'old_value': '01:29:00',
            'new_value': '01:29:00',
          },
          {
            'attendancedetail_id': 504,
            'old_value': '17:00:00',
            'new_value': '08:00:00',
          },
        ]);
      },
    );
  });

  group('Employee add vs edit requests', () {
    test('absent-day request omits punch fields and never sends --', () {
      final body = AttendanceService.editRequestBody(
        attendanceId: null,
        deviceDetails: 'iPhone',
        lat: 33.57,
        lon: 73.14,
        date: '2026-09-01',
        checkIn: null,
        checkOut: null,
        breakStart: null,
        breakEnd: null,
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
      expect(body.containsKey('check_in'), isFalse);
      expect(body.containsKey('check_out'), isFalse);
      expect(body['date'], '2026-09-01');
      expect(body['changes'], isEmpty);
    });

    test('absent-day request includes minted attendance id', () {
      final body = AttendanceService.editRequestBody(
        attendanceId: 190,
        deviceDetails: 'iPhone',
        lat: 33.57,
        lon: 73.14,
        date: '2026-09-09',
        checkIn: null,
        checkOut: null,
        changes: const [
          AttendanceChangeRequestPayload(
            attendanceDetailId: '901',
            oldValue: '00:00:00',
            newValue: '1:20 PM',
            type: 'check in',
          ),
          AttendanceChangeRequestPayload(
            attendanceDetailId: '902',
            oldValue: '00:03:00',
            newValue: '11:25 PM',
            type: 'check out',
          ),
        ],
      );

      expect(body['id'], 190);
      expect(body['attendance_id'], 190);
      expect(body['date'], '2026-09-09');
      expect(body.containsKey('check_in'), isFalse);
      expect(body['changes'], [
        {
          'attendancedetail_id': 901,
          'old_value': '00:00:00',
          'new_value': '13:20:00',
        },
        {
          'attendancedetail_id': 902,
          'old_value': '00:03:00',
          'new_value': '23:25:00',
        },
      ]);
    });

    test('parses attendance id from create/details envelopes', () {
      expect(
        AttendanceService.parseAttendanceId({
          'success': true,
          'data': {'attendance_id': 190},
        }),
        190,
      );
      expect(
        AttendanceService.parseAttendanceId({
          'data': {
            'attendance': {'id': 191},
          },
        }),
        191,
      );
      expect(
        AttendanceService.parseAttendanceId({'attendance_id': '192'}),
        192,
      );
    });

    test('existing-day edit keeps attendance_id and typed change rows', () {
      final body = AttendanceService.editRequestBody(
        attendanceId: 120,
        deviceDetails: 'iPhone',
        lat: 33.57,
        lon: 73.14,
        date: '2026-09-14',
        checkIn: null,
        checkOut: null,
        changes: const [
          AttendanceChangeRequestPayload(
            attendanceDetailId: '434',
            oldValue: '12:28 PM',
            newValue: '9:00 AM',
            type: 'check in',
          ),
        ],
      );

      expect(body['id'], 120);
      expect(body['attendance_id'], 120);
      expect(body.containsKey('check_in'), isFalse);
      expect((body['changes'] as List).single, {
        'attendancedetail_id': 434,
        'old_value': '12:28:00',
        'new_value': '09:00:00',
      });
    });
  });

  group('Pending add overlay', () {
    test('pending add keeps placeholder mints hidden until approved', () async {
      final store = AttendanceEditRequestStore.instance;
      final day = DateTime(2026, 9, 4);
      await store.addMany(
        day: day,
        requests: [
          AttendanceEditRequest(
            status: AttendanceEditRequestStatus.pending,
            requestedAt: DateTime(2026, 9, 14, 16, 27),
            originalTime: '--',
            newTime: '1:20 PM',
            eventType: 'checkIn',
          ),
        ],
      );

      final minted = AttendanceDayRecord(
        day: 4,
        weekday: 'Fri',
        date: day,
        checkIn: '00:00:00',
        status: AttendanceDayStatus.normal,
      );
      final overlayed = _overlayPendingAdd(minted, store);

      expect(store.hasPendingAdd(day), isTrue);
      expect(overlayed.status, AttendanceDayStatus.absent);
      expect(overlayed.isAbsent, isTrue);
    });

    test(
      'approved punches show on the list even if local pending add remains',
      () async {
        final store = AttendanceEditRequestStore.instance;
        final day = DateTime(2026, 9, 14);
        await store.addMany(
          day: day,
          requests: [
            AttendanceEditRequest(
              status: AttendanceEditRequestStatus.pending,
              requestedAt: DateTime(2026, 9, 14, 17, 2),
              originalTime: '--',
              newTime: '1:20 PM',
              eventType: 'checkIn',
            ),
          ],
        );

        final approved = AttendanceDayRecord(
          day: 14,
          weekday: 'Mon',
          date: day,
          checkIn: '13:20:00',
          checkOut: '17:25:00',
          status: AttendanceDayStatus.normal,
        );
        final overlayed = _overlayPendingAdd(approved, store);

        expect(store.hasPendingAdd(day), isTrue);
        expect(overlayed.checkIn, '13:20:00');
        expect(overlayed.checkOut, '17:25:00');
        expect(overlayed.isAbsent, isFalse);
      },
    );

    test(
      'keeps an existing punch visible when the request is an edit',
      () async {
        final store = AttendanceEditRequestStore.instance;
        final day = DateTime(2026, 9, 14);
        await store.addMany(
          day: day,
          requests: [
            AttendanceEditRequest(
              status: AttendanceEditRequestStatus.pending,
              requestedAt: DateTime(2026, 9, 14, 17, 2),
              originalTime: '12:28 PM',
              newTime: '9:00 AM',
              eventType: 'checkIn',
            ),
          ],
        );

        final punched = AttendanceDayRecord(
          day: 14,
          weekday: 'Mon',
          date: day,
          checkIn: '12:28 PM',
          checkOut: null,
          status: AttendanceDayStatus.normal,
        );
        final overlayed = _overlayPendingAdd(punched, store);

        expect(store.hasPending(day), isTrue);
        expect(store.hasPendingAdd(day), isFalse);
        expect(overlayed.status, AttendanceDayStatus.normal);
        expect(overlayed.checkIn, '12:28 PM');
      },
    );

    test('absent day with no request stays absent so add sheet can open', () {
      final store = AttendanceEditRequestStore.instance;
      final day = DateTime(2026, 9, 3);
      final absent = AttendanceDayRecord(
        day: 3,
        weekday: 'Thu',
        date: day,
        status: AttendanceDayStatus.absent,
      );

      expect(store.hasPending(day), isFalse);
      expect(_overlayPendingAdd(absent, store).isAbsent, isTrue);
    });

    test('clears pending add after the manager approves punches', () async {
      final store = AttendanceEditRequestStore.instance;
      final day = DateTime(2026, 9, 14);
      await store.addMany(
        day: day,
        requests: [
          AttendanceEditRequest(
            status: AttendanceEditRequestStatus.pending,
            requestedAt: DateTime(2026, 9, 14, 17, 33),
            originalTime: '--',
            newTime: '1:20 PM',
            eventType: 'checkIn',
          ),
        ],
      );
      expect(store.hasPendingAdd(day), isTrue);
      await store.clearPendingAdd(day);
      expect(store.hasPendingAdd(day), isFalse);
    });
  });

  group('Month history', () {
    test('keeps every history day instead of only today', () {
      final data = AttendanceHistoryData.fromJson({
        'today': '2026-09-14',
        'today_attendance': {'date': '2026-09-14', 'checkin': '12:28:00'},
        'history': [
          {'date': '2026-09-11', 'checkin': '09:01:00', 'checkout': '18:05:00'},
          {'date': '2026-09-04', 'checkin': '12:00:00', 'checkout': '20:00:00'},
        ],
      });

      expect(data.history.map((day) => day.date.day).toSet(), {14, 11, 4});
      expect(
        data.history.firstWhere((day) => day.date.day == 4).lastCheckOut,
        '20:00:00',
      );
    });
  });
}
