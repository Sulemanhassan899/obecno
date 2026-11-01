import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';

void main() {
  group('LeaveRequest status parsing', () {
    test('null / missing status matches attendance overlay (approved)', () {
      final leave = LeaveRequest.fromJson({
        'id': '1',
        'leave_type': 'Casual leave',
        'from_date': '2026-10-14',
        'to_date': '2026-10-14',
        'note': 'leave test',
      });
      expect(leave.status, LeaveRequestStatus.approved);
    });

    test('explicit pending stays pending', () {
      final leave = LeaveRequest.fromJson({
        'id': '2',
        'leave_type': 'Casual leave',
        'status': 'pending',
        'from_date': '2026-10-14',
        'to_date': '2026-10-14',
      });
      expect(leave.status, LeaveRequestStatus.pending);
    });

    test('approved string and approved_at are approved', () {
      expect(
        LeaveRequest.fromJson({
          'id': '3',
          'status': 'Approved',
          'from_date': '2026-10-14',
          'to_date': '2026-10-14',
        }).status,
        LeaveRequestStatus.approved,
      );
      expect(
        LeaveRequest.fromJson({
          'id': '4',
          'status': 'pending',
          'approved_at': '2026-10-14 15:00:00',
          'from_date': '2026-10-14',
          'to_date': '2026-10-14',
        }).status,
        LeaveRequestStatus.approved,
      );
    });

    test('numeric status without pending/rejected words is approved', () {
      final leave = LeaveRequest.fromJson({
        'id': '5',
        'status': 1,
        'from_date': '2026-10-14',
        'to_date': '2026-10-14',
      });
      expect(leave.status, LeaveRequestStatus.approved);
    });

    test('rejected is rejected', () {
      final leave = LeaveRequest.fromJson({
        'id': '6',
        'status': 'rejected',
        'from_date': '2026-10-14',
        'to_date': '2026-10-14',
      });
      expect(leave.status, LeaveRequestStatus.rejected);
    });
  });
}
