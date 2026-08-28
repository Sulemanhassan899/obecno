import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_filters.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class LocationAttendanceStats {
  const LocationAttendanceStats({
    required this.active,
    required this.total,
    required this.lateCheckIns,
  });

  final int active;
  final int total;
  final int lateCheckIns;

  factory LocationAttendanceStats.of({
    required ManagerLocationModel location,
    required List<ManagerTeamAttendanceItem> attendance,
    required List<ManagerEmployeeModel> members,
  }) {
    final merged = merge(
      location: location,
      attendance: attendance,
      members: members,
    );
    return LocationAttendanceStats(
      active: merged.where((item) => item.hasCheckIn).length,
      total: merged.length,
      lateCheckIns: merged.where((item) => item.isLate).length,
    );
  }

  /// Assigned people for [location], plus anyone who punched there (e.g. Owner).
  static List<ManagerTeamAttendanceItem> merge({
    required ManagerLocationModel location,
    required List<ManagerTeamAttendanceItem> attendance,
    required List<ManagerEmployeeModel> members,
  }) {
    final assigned = ManagerEmployeeFilters.byLocation(
      source: members,
      selectedLocationId: location.id,
      selectedLocationName: location.name,
    );

    final merged = List<ManagerTeamAttendanceItem>.from(
      assigned.isEmpty
          ? attendance.where((item) => matchesLocation(item, location))
          : TeamAttendanceMapper.mergeWithMembers(
              attendance: attendance,
              members: assigned,
              includeUnmatchedAttendance: false,
            ),
    );

    final seen = <String>{
      for (final item in merged)
        if (_key(item).isNotEmpty) _key(item),
    };
    for (final item in attendance) {
      if (!item.hasCheckIn) continue;
      if (!matchesLocation(item, location)) continue;
      final key = _key(item);
      if (key.isEmpty || seen.contains(key)) continue;
      merged.add(item);
      seen.add(key);
    }
    return merged;
  }

  /// Snapshot present/total/late onto each location. Uncounted owner punches
  /// land on their assigned office, or the only office if there is just one.
  static List<ManagerLocationModel> stamp({
    required List<ManagerLocationModel> locations,
    required List<ManagerTeamAttendanceItem> attendance,
    required List<ManagerEmployeeModel> members,
  }) {
    if (locations.isEmpty) return locations;

    final stamped = <ManagerLocationModel>[];
    final countedPresent = <String>{};

    for (final location in locations) {
      final merged = merge(
        location: location,
        attendance: attendance,
        members: members,
      );
      for (final item in merged) {
        if (item.hasCheckIn) {
          final key = _key(item);
          if (key.isNotEmpty) countedPresent.add(key);
        }
      }
      stamped.add(
        location.copyWith(
          present: merged.where((item) => item.hasCheckIn).length,
          total: merged.length,
          lateCheckIns: merged.where((item) => item.isLate).length,
        ),
      );
    }

    for (final item in attendance) {
      if (!item.hasCheckIn) continue;
      final key = _key(item);
      if (key.isEmpty || countedPresent.contains(key)) continue;
      if (!_looksLikeOwner(item, members)) continue;

      final index = _fallbackLocationIndex(
        locations: locations,
        item: item,
        members: members,
      );
      if (index == null) continue;

      final location = stamped[index];
      stamped[index] = location.copyWith(
        present: location.present + 1,
        total: location.total + 1,
      );
      countedPresent.add(key);
    }
    return stamped;
  }

  static bool matchesLocation(
    ManagerTeamAttendanceItem item,
    ManagerLocationModel location,
  ) {
    final id = location.id.trim().toLowerCase();
    if (id.isNotEmpty && (item.locationId ?? '').trim().toLowerCase() == id) {
      return true;
    }
    final name = location.name.trim().toLowerCase();
    if (name.isEmpty) return false;
    return [item.locationName ?? '', item.currentLocation ?? ''].any((value) {
      final text = value.trim().toLowerCase();
      if (text.isEmpty) return false;
      return text == name || text.contains(name) || name.contains(text);
    });
  }

  static String _key(ManagerTeamAttendanceItem item) {
    return (item.userId?.toString() ?? item.employeeName ?? '')
        .trim()
        .toLowerCase();
  }

  static bool _looksLikeOwner(
    ManagerTeamAttendanceItem item,
    List<ManagerEmployeeModel> members,
  ) {
    final name = (item.employeeName ?? '').trim().toLowerCase();
    if (name == 'owner' || name.contains('owner')) return true;
    for (final member in members) {
      final samePerson =
          (item.userId != null && member.userId == item.userId) ||
          (item.userId != null && member.id.trim() == item.userId.toString());
      if (!samePerson) continue;
      if (member.badge == ManagerEmployeeBadge.owner) return true;
      if (member.role.toLowerCase().contains('owner')) return true;
      if ((member.departmentTitle ?? '').toLowerCase().contains('owner')) {
        return true;
      }
      if (member.name.trim().toLowerCase().contains('owner')) return true;
    }
    return false;
  }

  static int? _fallbackLocationIndex({
    required List<ManagerLocationModel> locations,
    required ManagerTeamAttendanceItem item,
    required List<ManagerEmployeeModel> members,
  }) {
    for (final member in members) {
      final samePerson =
          (item.userId != null && member.userId == item.userId) ||
          (item.userId != null && member.id.trim() == item.userId.toString());
      if (!samePerson &&
          (item.employeeName ?? '').trim().toLowerCase() !=
              member.name.trim().toLowerCase()) {
        continue;
      }
      for (var i = 0; i < locations.length; i++) {
        if (member.assignedToLocation(
          id: locations[i].id,
          name: locations[i].name,
        )) {
          return i;
        }
      }
    }
    if (locations.length == 1) return 0;
    return null;
  }
}
