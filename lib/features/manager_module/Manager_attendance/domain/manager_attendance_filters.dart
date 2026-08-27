import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_filters.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';

/// Pure filter helpers for manager team attendance (testable without UI).
class ManagerAttendanceFilters {
  ManagerAttendanceFilters._();

  static bool isAllStatus(String? selectedStatus) {
    final value = (selectedStatus ?? '').trim();
    if (value.isEmpty) return true;
    final id = StatusFilterOption.idFromLabel(value);
    return id == StatusFilterOption.allId;
  }

  static bool isAllLocations(String? selectedLocation) {
    final value = (selectedLocation ?? '').trim();
    if (value.isEmpty) return true;
    return value == LocationFilterOption.allId ||
        value.toLowerCase() == 'all locations' ||
        value.toLowerCase() == 'locations';
  }

  static String statusDisplayLabel(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'working':
      case 'active':
        return 'Active / Working';
      case 'break':
      case 'on break':
      case 'onbreak':
      case 'on_break':
        return 'On Break';
      case 'late':
      case 'late check-in':
      case 'late_checkin':
        return 'Late Check-in';
      case 'early':
      case 'early check-out':
      case 'early_checkout':
        return 'Early Check-Out';
      case 'leave':
      case 'on leave':
      case 'on leaves':
        return 'On Leaves';
      case 'absent':
      case '':
        return 'Absent';
      case 'present':
        return 'Present Today';
      default:
        return raw;
    }
  }

  static bool matchesStatus(
    ManagerTeamAttendanceItem item,
    String selectedStatus,
  ) {
    if (isAllStatus(selectedStatus)) return true;
    final id = StatusFilterOption.idFromLabel(selectedStatus);

    if (StatusFilterOption.sameFamily(id, 'present')) return item.hasCheckIn;
    if (StatusFilterOption.sameFamily(id, 'working')) return item.isActive;
    if (StatusFilterOption.sameFamily(id, 'break')) return item.isOnBreak;
    if (StatusFilterOption.sameFamily(id, 'late')) return item.isLate;
    if (StatusFilterOption.sameFamily(id, 'leave')) return item.isOnLeave;
    if (StatusFilterOption.sameFamily(id, 'absent')) return item.isAbsent;
    if (StatusFilterOption.sameFamily(id, 'early_checkout')) {
      return item.isEarlyCheckout;
    }

    final raw = item.status ?? '';
    final label = item.statusLabel ?? '';
    return StatusFilterOption.sameFamily(raw, id) ||
        StatusFilterOption.sameFamily(label, selectedStatus) ||
        StatusFilterOption.sameFamily(raw, selectedStatus);
  }

  static bool matchesLocation(
    ManagerTeamAttendanceItem item, {
    required String selectedLocation,
    String? locationName,
  }) {
    if (isAllLocations(selectedLocation)) return true;
    final selected = selectedLocation.trim().toLowerCase();
    final id = (item.locationId ?? '').trim().toLowerCase();
    if (id.isNotEmpty && id == selected) return true;

    final targetName = (locationName ?? '').trim().toLowerCase();
    if (targetName.isEmpty) return false;
    return [
      item.locationName ?? '',
      item.currentLocation ?? '',
    ].any((name) => name.trim().toLowerCase() == targetName);
  }

  /// Prefer assigned employees for a location over punch `location_id`.
  static List<ManagerTeamAttendanceItem> byAssignedLocation({
    required List<ManagerTeamAttendanceItem> source,
    required List<ManagerEmployeeModel> members,
    required String selectedLocation,
    String? locationName,
  }) {
    if (isAllLocations(selectedLocation)) {
      return List<ManagerTeamAttendanceItem>.from(source);
    }

    final assigned = ManagerEmployeeFilters.byLocation(
      source: members,
      selectedLocationId: selectedLocation,
      selectedLocationName: locationName,
    );

    if (assigned.isEmpty) {
      // Fall back to punch/current location tags when directory has no match.
      return source
          .where(
            (item) => matchesLocation(
              item,
              selectedLocation: selectedLocation,
              locationName: locationName,
            ),
          )
          .toList(growable: false);
    }

    final ids = <String>{
      for (final member in assigned)
        if (member.id.trim().isNotEmpty) member.id.trim(),
    };

    return source
        .where((item) {
          final userId = item.userId?.toString();
          return userId != null && ids.contains(userId);
        })
        .toList(growable: false);
  }

  static List<ManagerTeamAttendanceItem> applyItems({
    required List<ManagerTeamAttendanceItem> source,
    String selectedStatus = 'all',
    String selectedLocation = 'all',
    String? locationName,
    String searchQuery = '',
    List<ManagerEmployeeModel> members = const [],
  }) {
    var list = List<ManagerTeamAttendanceItem>.from(source);

    if (!isAllLocations(selectedLocation)) {
      list = byAssignedLocation(
        source: list,
        members: members,
        selectedLocation: selectedLocation,
        locationName: locationName,
      );
    }

    if (!isAllStatus(selectedStatus)) {
      list = list.where((item) => matchesStatus(item, selectedStatus)).toList();
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((item) => (item.employeeName ?? '').toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  static List<ManagerAttendanceModel> apply({
    required List<ManagerAttendanceModel> source,
    String selectedStatus = 'All Status',
    String selectedLocation = 'All Locations',
    String searchQuery = '',
  }) {
    var list = List<ManagerAttendanceModel>.from(source);

    if (!isAllStatus(selectedStatus)) {
      list = list
          .where(
            (item) =>
                StatusFilterOption.sameFamily(item.status, selectedStatus) ||
                statusDisplayLabel(item.status).toLowerCase() ==
                    selectedStatus.toLowerCase(),
          )
          .toList();
    }

    if (!isAllLocations(selectedLocation)) {
      final selected = selectedLocation.trim().toLowerCase();
      list = list
          .where((item) => (item.team ?? '').toLowerCase() == selected)
          .toList();
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) => e.name.toLowerCase().contains(q)).toList();
    }

    return list;
  }
}
