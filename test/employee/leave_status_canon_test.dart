import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/employee_module/leaves/data/leave_status.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';

void main() {
  group('LeaveStatusCanon', () {
    test('maps pending synonyms', () {
      for (final raw in ['pending', 'requested', 'awaiting', 'submitted', '0']) {
        expect(
          LeaveStatusCanon.fromRaw(raw),
          LeaveRequestStatus.pending,
          reason: raw,
        );
      }
    });

    test('maps approved synonyms', () {
      for (final raw in ['approved', 'accepted', '1', 'true']) {
        expect(
          LeaveStatusCanon.fromRaw(raw),
          LeaveRequestStatus.approved,
          reason: raw,
        );
      }
    });

    test('maps rejected synonyms', () {
      for (final raw in ['rejected', 'denied', 'declined', 'cancelled']) {
        expect(
          LeaveStatusCanon.fromRaw(raw),
          LeaveRequestStatus.rejected,
          reason: raw,
        );
      }
    });

    test('blank respects assumeApprovedQuery', () {
      expect(
        LeaveStatusCanon.fromRaw('', assumeApprovedQuery: true),
        LeaveRequestStatus.approved,
      );
      expect(
        LeaveStatusCanon.fromRaw('', assumeApprovedQuery: false),
        LeaveRequestStatus.pending,
      );
    });
  });
}
