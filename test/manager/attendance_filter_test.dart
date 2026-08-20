import 'package:Obecno/demo/demo_list.dart';
import 'package:Obecno/features/manager_module/Manager_attendance/domain/manager_attendance_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManagerAttendanceFilters', () {
    test('maps status labels', () {
      expect(
        ManagerAttendanceFilters.statusDisplayLabel('working'),
        'Active / Working',
      );
      expect(ManagerAttendanceFilters.statusDisplayLabel('late'), 'Late Check-in');
      expect(ManagerAttendanceFilters.statusDisplayLabel('leave'), 'Absent');
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
  });
}
