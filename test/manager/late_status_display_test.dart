import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

void main() {
  group('Late status on manager attendance tiles', () {
    test('uiStatus returns late when isLate is true', () {
      const item = ManagerTeamAttendanceItem(
        employeeName: 'Employee1',
        checkin: '10:50:00',
        isLate: true,
        isOpen: true,
      );
      expect(TeamAttendanceMapper.uiStatus(item), 'late');
      expect(TeamAttendanceMapper.toTile(item).status, 'late');
      expect(TeamAttendanceMapper.toTile(item).checkOut, isNull);
    });

    test('live_status late maps to late tile status', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 3,
        'employee_name': 'Employee1',
        'check_in_time': '10:50:00',
        'live_status': 'late',
        'is_open': true,
      });
      expect(item.isLate, isTrue);
      expect(TeamAttendanceMapper.uiStatus(item), 'late');
      expect(TeamAttendanceMapper.toTile(item).status, 'late');
    });

    test('is_late with working live_status still maps to late', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 3,
        'employee_name': 'Employee1',
        'check_in': '10:50:00',
        'live_status': 'working',
        'is_late': true,
        'is_open': true,
      });
      expect(item.isLate, isTrue);
      expect(TeamAttendanceMapper.uiStatus(item), 'late');
      expect(TeamAttendanceMapper.toTile(item).status, 'late');
    });

    test('late_check_in flag maps to late', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 3,
        'employee_name': 'Employee1',
        'check_in': '10:50:00',
        'late_check_in': true,
      });
      expect(item.isLate, isTrue);
      expect(TeamAttendanceMapper.uiStatus(item), 'late');
    });

    test('flags.is_late maps to late', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 3,
        'employee_name': 'Employee1',
        'check_in': '10:50:00',
        'live_status': 'working',
        'flags': {'is_late': true},
      });
      expect(item.isLate, isTrue);
      expect(TeamAttendanceMapper.uiStatus(item), 'late');
      expect(TeamAttendanceMapper.toTile(item).status, 'late');
    });

    test('status Late Check-in maps to late via isLate', () {
      final item = ManagerTeamAttendanceItem.fromJson({
        'user_id': 3,
        'employee_name': 'Employee1',
        'check_in': '10:50:00',
        'status': 'Late Check-in',
      });
      expect(item.isLate, isTrue);
      expect(TeamAttendanceMapper.uiStatus(item), 'late');
    });

    test('late takes priority over working for open sessions', () {
      const item = ManagerTeamAttendanceItem(
        employeeName: 'Employee1',
        checkin: '10:50:00',
        isLate: true,
        isOpen: true,
        status: 'working',
      );
      expect(TeamAttendanceMapper.uiStatus(item), 'late');
    });

    test('break still takes priority over late', () {
      const item = ManagerTeamAttendanceItem(
        employeeName: 'Employee1',
        checkin: '10:50:00',
        breakout: '12:00:00',
        isLate: true,
        isOpen: true,
      );
      expect(TeamAttendanceMapper.uiStatus(item), 'break');
    });
  });
}
