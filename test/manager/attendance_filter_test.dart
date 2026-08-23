import 'package:obecno/demo/demo_list.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/manager_attendance_filters.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      expect(tile.checkOut, '05:07 PM');
      expect(tile.status, 'working');
      expect(tile.team, 'Head Office');
    });
  });
}
