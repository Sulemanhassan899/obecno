import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';

class EmployeeDirectoryCounts {
  const EmployeeDirectoryCounts({
    required this.total,
    required this.active,
    required this.pending,
    required this.disabled,
  });

  final int total;
  final int active;
  final int pending;
  final int disabled;

  factory EmployeeDirectoryCounts.from(List<ManagerEmployeeModel> employees) {
    return EmployeeDirectoryCounts(
      total: employees.length,
      active: employees
          .where((e) => e.status == ManagerEmployeeStatus.active)
          .length,
      pending: employees
          .where((e) => e.status == ManagerEmployeeStatus.pending)
          .length,
      disabled: employees
          .where((e) => e.status == ManagerEmployeeStatus.disabled)
          .length,
    );
  }
}

class ManagerEmployeeFilters {
  ManagerEmployeeFilters._();

  static const allLocationId = LocationFilterOption.allId;

  static List<ManagerEmployeeModel> byLocation({
    required List<ManagerEmployeeModel> source,
    required String selectedLocationId,
  }) {
    if (selectedLocationId == LocationFilterOption.allId) {
      return List.from(source);
    }
    final hasLocationIds = source.any(
      (e) => e.locationId != null && e.locationId!.isNotEmpty,
    );
    if (!hasLocationIds) return List.from(source);
    return source.where((e) => e.locationId == selectedLocationId).toList();
  }

  static List<ManagerEmployeeModel> byQuery({
    required List<ManagerEmployeeModel> source,
    required String query,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.from(source);
    return source
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.role.toLowerCase().contains(q) ||
              (e.departmentTitle ?? '').toLowerCase().contains(q),
        )
        .toList();
  }
}
