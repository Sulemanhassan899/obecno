import 'package:Obecno/demo/manager_employee_model.dart';
import 'package:Obecno/features/manager_module/Manager_employees/domain/manager_employee_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManagerEmployeeFilters', () {
    test('filters by location', () {
      final north = ManagerEmployeeFilters.byLocation(
        source: dummyManagerEmployees,
        selectedLocationId: 'north',
      );
      expect(north, isNotEmpty);
      expect(north.every((e) => e.locationId == 'north'), isTrue);
    });

    test('all location returns everyone', () {
      final all = ManagerEmployeeFilters.byLocation(
        source: dummyManagerEmployees,
        selectedLocationId: ManagerEmployeeFilters.allLocationId,
      );
      expect(all.length, dummyManagerEmployees.length);
    });

    test('filters by name query', () {
      final found = ManagerEmployeeFilters.byQuery(
        source: dummyManagerEmployees,
        query: 'ava',
      );
      expect(found, isNotEmpty);
      expect(found.first.name.toLowerCase(), contains('ava'));
    });
  });
}
