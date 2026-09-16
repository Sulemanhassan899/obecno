import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_edit_request_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AttendanceEditRequestStore.instance.debugReset();
  });

  test('pending add requests keep the day absent until approved', () {
    final add = AttendanceEditRequest(
      status: AttendanceEditRequestStatus.pending,
      requestedAt: DateTime(2026, 9, 14, 16, 27),
      originalTime: '--',
      newTime: '9:00 AM',
      eventType: 'checkIn',
    );
    final edit = AttendanceEditRequest(
      status: AttendanceEditRequestStatus.pending,
      requestedAt: DateTime(2026, 9, 14, 16, 27),
      originalTime: '12:28 PM',
      newTime: '9:00 AM',
      eventType: 'checkIn',
    );

    expect(add.isPendingAdd, isTrue);
    expect(edit.isPendingAdd, isFalse);
  });

  test('store finds pending add requests for a day', () async {
    final store = AttendanceEditRequestStore.instance;
    final day = DateTime(2026, 9, 4);
    await store.addMany(
      day: day,
      requests: [
        AttendanceEditRequest(
          status: AttendanceEditRequestStatus.pending,
          requestedAt: DateTime(2026, 9, 14, 16, 27),
          originalTime: '--',
          newTime: '9:00 AM',
          eventType: 'checkIn',
        ),
        AttendanceEditRequest(
          status: AttendanceEditRequestStatus.pending,
          requestedAt: DateTime(2026, 9, 14, 16, 27),
          originalTime: '--',
          newTime: '6:00 PM',
          eventType: 'checkOut',
        ),
      ],
    );

    expect(store.hasPending(day), isTrue);
    expect(store.hasPendingAdd(day), isTrue);
    expect(store.forDay(day), hasLength(2));
    expect(store.hasPendingAdd(DateTime(2026, 9, 5)), isFalse);
  });
}
