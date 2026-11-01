import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/alerts/services/leave_alert_store.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class _MemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

ManagerTeamLeaveItem leave({
  required int id,
  required String status,
  String? statusLabel,
  String from = '2026-10-20',
  String to = '2026-10-21',
  String? sourceId,
}) {
  return ManagerTeamLeaveItem(
    id: id,
    userId: 7,
    employeeName: 'Alex',
    dateFrom: from,
    dateTo: to,
    status: status,
    statusLabel: statusLabel,
    leaveType: 'Casual leave',
    sourceId: sourceId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LeaveAlertStore employee decision archive', () {
    late _MemorySecureStorage storage;
    late LeaveAlertStore store;

    setUp(() {
      storage = _MemorySecureStorage();
      store = LeaveAlertStore(storage: storage, namespace: 'employee');
    });

    test('mergeDecided keeps approved and rejected, skips pending', () async {
      final merged = await store.mergeDecided([
        leave(id: 1, status: 'approved', statusLabel: 'Approved'),
        leave(id: 2, status: 'rejected', statusLabel: 'Rejected'),
        leave(id: 3, status: 'pending', statusLabel: 'Pending'),
      ]);

      expect(merged.map((e) => e.id), containsAll([1, 2]));
      expect(merged.any((e) => e.id == 3), isFalse);
      expect(merged.firstWhere((e) => e.id == 1).countsAsOnLeave, isTrue);
      expect(merged.firstWhere((e) => e.id == 2).isRejectedLeave, isTrue);
    });

    test('mergeDecided upserts status flips for the same leave key', () async {
      await store.mergeDecided([
        leave(id: 10, status: 'approved', statusLabel: 'Approved'),
      ]);
      final afterReject = await store.mergeDecided([
        leave(id: 10, status: 'rejected', statusLabel: 'Rejected'),
      ]);

      expect(afterReject, hasLength(1));
      expect(afterReject.single.isRejectedLeave, isTrue);
      expect(afterReject.single.alertKey, 'leave_10');
    });

    test('notified keys dedupe approve vs reject separately', () async {
      const approveKey = 'leave_10:approved';
      const rejectKey = 'leave_10:rejected';

      expect(store.wasNotified(approveKey), isFalse);
      await store.markNotified(approveKey);
      expect(store.wasNotified(approveKey), isTrue);
      expect(store.wasNotified(rejectKey), isFalse);

      await store.markNotified(rejectKey);
      expect(store.wasNotified(rejectKey), isTrue);
    });

    test('employee namespace does not share manager storage keys', () async {
      final manager = LeaveAlertStore(storage: storage, namespace: 'manager');
      await store.mergeDecided([
        leave(id: 1, status: 'approved', statusLabel: 'Approved'),
      ]);
      await manager.mergePending([
        leave(id: 99, status: 'pending', statusLabel: 'Pending'),
      ]);

      expect(store.items.single.id, 1);
      expect(manager.items.single.id, 99);
      expect(storage.data.keys, contains('alerts_leave_archive_employee_v1'));
      expect(storage.data.keys, contains('alerts_leave_archive_v1'));
    });
  });

  group('LeaveAlertStore manager pending archive', () {
    late LeaveAlertStore store;

    setUp(() {
      store = LeaveAlertStore(
        storage: _MemorySecureStorage(),
        namespace: 'manager',
      );
    });

    test('mergePending keeps pending rows and markReviewed flips status',
        () async {
      await store.mergePending([
        leave(id: 5, status: 'pending', statusLabel: 'Pending'),
      ]);
      expect(store.items.single.isPendingInInbox, isTrue);

      await store.markReviewed(key: 'leave_5', action: 'approve');
      expect(store.items.single.countsAsOnLeave, isTrue);
      expect(store.items.single.isPendingInInbox, isFalse);
    });

    test('mergePending does not overwrite a locally reviewed row', () async {
      await store.mergePending([
        leave(id: 8, status: 'pending'),
      ]);
      await store.markReviewed(key: 'leave_8', action: 'reject');

      final merged = await store.mergePending([
        leave(id: 8, status: 'pending', statusLabel: 'Pending'),
      ]);

      expect(merged.single.isRejectedLeave, isTrue);
      expect(merged.single.isPendingInInbox, isFalse);
    });
  });

  group('ManagerTeamLeaveItem inbox classification', () {
    test('approved counts as on leave; rejected and pending do not', () {
      expect(
        leave(id: 1, status: 'approved', statusLabel: 'Approved')
            .countsAsOnLeave,
        isTrue,
      );
      expect(
        leave(id: 2, status: 'rejected', statusLabel: 'Rejected')
            .countsAsOnLeave,
        isFalse,
      );
      expect(
        leave(id: 2, status: 'rejected').isRejectedLeave,
        isTrue,
      );
      expect(
        leave(id: 3, status: 'pending').isPendingInInbox,
        isTrue,
      );
      expect(
        leave(id: 3, status: 'pending').countsAsOnLeave,
        isFalse,
      );
    });

    test('alertKey prefers sourceId then numeric id', () {
      expect(
        leave(id: 4, status: 'approved', sourceId: '42').alertKey,
        'leave_42',
      );
      expect(leave(id: 4, status: 'approved').alertKey, 'leave_4');
      expect(
        leave(id: 4, status: 'approved', sourceId: 'leave_42').alertKey,
        'leave_42',
      );
    });
  });
}
