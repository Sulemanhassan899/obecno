import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
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
  static const allStatusId = StatusFilterOption.allId;

  static const directoryStatusOptions = <StatusFilterOption>[
    StatusFilterOption.all,
    StatusFilterOption(id: 'active', label: 'Active', dotColor: kPrimaryColor),
    StatusFilterOption(id: 'pending', label: 'Pending', dotColor: kYellowColor),
    StatusFilterOption(id: 'disabled', label: 'Disabled', dotColor: kredColor),
  ];

  static List<ManagerEmployeeModel> byLocation({
    required List<ManagerEmployeeModel> source,
    required String selectedLocationId,
    String? selectedLocationName,
  }) {
    if (selectedLocationId == LocationFilterOption.allId) {
      return List.from(source);
    }
    final canFilterLocally = source.any(
      (e) =>
          (e.locationId != null && e.locationId!.isNotEmpty) ||
          e.locationIds.isNotEmpty ||
          (e.locationName != null && e.locationName!.isNotEmpty),
    );
    if (!canFilterLocally) return List.from(source);
    return source
        .where(
          (e) => e.assignedToLocation(
            id: selectedLocationId,
            name: selectedLocationName,
          ),
        )
        .toList();
  }

  static List<ManagerEmployeeModel> byStatus({
    required List<ManagerEmployeeModel> source,
    required String selectedStatusId,
  }) {
    final status = statusFromFilterId(selectedStatusId);
    if (status == null) return List.from(source);
    return source.where((e) => e.status == status).toList();
  }

  static ManagerEmployeeStatus? statusFromFilterId(String selectedStatusId) {
    switch (selectedStatusId.trim().toLowerCase()) {
      case 'active':
        return ManagerEmployeeStatus.active;
      case 'pending':
        return ManagerEmployeeStatus.pending;
      case 'disabled':
        return ManagerEmployeeStatus.disabled;
      case 'deleted':
        return ManagerEmployeeStatus.deleted;
      default:
        return null;
    }
  }

  static String statusChipLabel(String selectedStatusId) {
    if (selectedStatusId.trim().isEmpty || selectedStatusId == allStatusId) {
      return 'Status';
    }
    return StatusFilterOption.displayLabel(
      selectedStatusId,
      directoryStatusOptions,
    );
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

  /// You first, then owner / team lead / manager / other non-employee roles.
  static List<ManagerEmployeeModel> roleFirst(
    List<ManagerEmployeeModel> source,
  ) {
    final ranked = List<ManagerEmployeeModel>.from(source)
      ..sort((a, b) {
        final byRole = _roleRank(a).compareTo(_roleRank(b));
        if (byRole != 0) return byRole;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return ranked;
  }

  static int _roleRank(ManagerEmployeeModel employee) {
    final text =
        '${employee.role} ${employee.name} ${employee.badgeLabel ?? ''}'
            .toLowerCase();

    if (employee.badge == ManagerEmployeeBadge.you) return 0;
    if (employee.badge == ManagerEmployeeBadge.owner ||
        text.contains('owner') ||
        text.contains('ceo')) {
      return 1;
    }
    if (text.contains('team lead') ||
        text.contains('team_lead') ||
        text.contains('teamlead')) {
      return 2;
    }
    if (employee.badge == ManagerEmployeeBadge.manager ||
        text.contains('manager')) {
      return 3;
    }
    if (!employee.isRegularEmployee) return 4;
    return 5;
  }
}
