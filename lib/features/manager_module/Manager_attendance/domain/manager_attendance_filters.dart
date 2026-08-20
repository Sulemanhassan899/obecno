import 'package:Obecno/demo/manager_attendence_model.dart';

/// Pure filter helpers for manager team attendance (testable without UI).
class ManagerAttendanceFilters {
  ManagerAttendanceFilters._();

  static String statusDisplayLabel(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'working':
      case 'active':
        return 'Active / Working';
      case 'break':
      case 'on break':
      case 'onbreak':
        return 'On Break';
      case 'late':
      case 'late check-in':
        return 'Late Check-in';
      case 'early':
      case 'early check-out':
      case 'early_checkout':
        return 'Early Check-Out';
      case 'leave':
      case 'on leave':
      case 'absent':
      case '':
        return 'Absent';
      case 'present':
        return 'Present Today';
      default:
        return raw;
    }
  }

  static List<ManagerAttendanceModel> apply({
    required List<ManagerAttendanceModel> source,
    String selectedStatus = 'All Status',
    String selectedLocation = 'All Locations',
    String searchQuery = '',
  }) {
    final isAllStatus =
        selectedStatus == 'All Status' || selectedStatus == 'Status';
    final isAllLocations =
        selectedLocation == 'All Locations' || selectedLocation == 'Locations';

    var list = List<ManagerAttendanceModel>.from(source);

    if (!isAllStatus) {
      list = list
          .where(
            (item) =>
                statusDisplayLabel(item.status).toLowerCase() ==
                selectedStatus.toLowerCase(),
          )
          .toList();
    }

    if (!isAllLocations) {
      list = list
          .where(
            (item) =>
                (item.team ?? '').toLowerCase() ==
                selectedLocation.toLowerCase(),
          )
          .toList();
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) => e.name.toLowerCase().contains(q)).toList();
    }

    return list;
  }
}
