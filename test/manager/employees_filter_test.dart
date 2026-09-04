import 'package:obecno/demo/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_filters.dart';
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

    test('filters by account status', () {
      final pending = ManagerEmployeeFilters.byStatus(
        source: dummyManagerEmployees,
        selectedStatusId: 'pending',
      );
      expect(pending, isNotEmpty);
      expect(
        pending.every((e) => e.status == ManagerEmployeeStatus.pending),
        isTrue,
      );

      final all = ManagerEmployeeFilters.byStatus(
        source: dummyManagerEmployees,
        selectedStatusId: ManagerEmployeeFilters.allStatusId,
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

    test('matches location by nested locations and name', () {
      final employee = ManagerEmployeeModel.fromJson({
        'id': '31',
        'name': 'Employee3',
        'role': 'Employee',
        'locations': [
          {'id': '5', 'name': 'i-10 cowork'},
        ],
      });
      expect(employee.assignedToLocation(id: '5', name: 'i-10 cowork'), isTrue);
      expect(
        employee.assignedToLocation(id: '9', name: 'Head Office'),
        isFalse,
      );

      final filtered = ManagerEmployeeFilters.byLocation(
        source: [employee, dummyManagerEmployees.first],
        selectedLocationId: '5',
        selectedLocationName: 'i-10 cowork',
      );
      expect(filtered, [employee]);
    });

    test('puts me first, then owner, team lead, manager, then employees', () {
      const source = [
        ManagerEmployeeModel(id: '1', name: 'Employee3', role: 'Employee'),
        ManagerEmployeeModel(id: '2', name: 'Employee1', role: 'Sales'),
        ManagerEmployeeModel(id: '3', name: 'Manager 1', role: 'Sales'),
        ManagerEmployeeModel(id: '4', name: 'Zara', role: 'Team Lead'),
        ManagerEmployeeModel(
          id: '5',
          name: 'Owner',
          role: 'Sales',
          badge: ManagerEmployeeBadge.you,
        ),
      ];

      expect(ManagerEmployeeFilters.roleFirst(source).map((e) => e.name), [
        'Owner',
        'Zara',
        'Manager 1',
        'Employee1',
        'Employee3',
      ]);
    });
  });
}
