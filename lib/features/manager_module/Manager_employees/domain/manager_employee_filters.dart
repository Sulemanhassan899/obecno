import 'package:Obecno/demo/manager_employee_model.dart';
import 'package:Obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';

/// Pure filter helpers for manager employees list (testable without UI).
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
              e.role.toLowerCase().contains(q),
        )
        .toList();
  }
}
