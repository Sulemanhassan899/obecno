import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/employee_location_assignment.dart';

void main() {
  group('EmployeeLocationSavePayload.fromAssigned', () {
    test('keeps the current default when it is still assigned', () {
      final payload = EmployeeLocationSavePayload.fromAssigned(
        selectedIds: {'1', '2', '3'},
        currentDefaultId: '2',
      );
      expect(payload.defaultLocationId, '2');
      expect(payload.locationIds, ['1', '2', '3']);
    });

    test('falls back to the first remaining location when default is removed', () {
      final payload = EmployeeLocationSavePayload.fromAssigned(
        selectedIds: {'3', '4'},
        currentDefaultId: '1',
      );
      expect(payload.defaultLocationId, '3');
      expect(payload.locationIds, ['3', '4']);
    });

    test('returns an empty default when nothing is assigned', () {
      final payload = EmployeeLocationSavePayload.fromAssigned(
        selectedIds: const {},
        currentDefaultId: '1',
      );
      expect(payload.defaultLocationId, isEmpty);
      expect(payload.locationIds, isEmpty);
    });
  });

  group('EmployeeLocationSavePayload.afterRemovingLocation', () {
    test('removes the deactivated office and keeps another default', () {
      final payload = EmployeeLocationSavePayload.afterRemovingLocation(
        assignedIds: {'1', '2', '3'},
        removedLocationId: '2',
        currentDefaultId: '1',
      );
      expect(payload.locationIds, containsAll(['1', '3']));
      expect(payload.locationIds, isNot(contains('2')));
      expect(payload.defaultLocationId, '1');
    });

    test('promotes the next location when default is deactivated', () {
      final payload = EmployeeLocationSavePayload.afterRemovingLocation(
        assignedIds: {'bhara', 'office-2'},
        removedLocationId: 'bhara',
        currentDefaultId: 'bhara',
      );
      expect(payload.locationIds, ['office-2']);
      expect(payload.defaultLocationId, 'office-2');
    });

    test('clears assignment when the only office is deactivated', () {
      final payload = EmployeeLocationSavePayload.afterRemovingLocation(
        assignedIds: {'bhara'},
        removedLocationId: 'bhara',
        currentDefaultId: 'bhara',
      );
      expect(payload.locationIds, isEmpty);
      expect(payload.defaultLocationId, isEmpty);
    });
  });

  group('EmployeeLocationSavePayload.fromDefault', () {
    test('adds the new default to assigned locations', () {
      final payload = EmployeeLocationSavePayload.fromDefault(
        assignedIds: {'1', '2'},
        newDefaultId: '9',
      );
      expect(payload.defaultLocationId, '9');
      expect(payload.locationIds, containsAll(['1', '2', '9']));
    });

    test('does not duplicate an already assigned default', () {
      final payload = EmployeeLocationSavePayload.fromDefault(
        assignedIds: {'1', '2'},
        newDefaultId: '2',
      );
      expect(payload.defaultLocationId, '2');
      expect(payload.locationIds, ['1', '2']);
    });
  });
}
