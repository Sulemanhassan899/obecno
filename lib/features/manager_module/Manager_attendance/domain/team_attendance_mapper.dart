import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class TeamAttendanceMapper {
  TeamAttendanceMapper._();

  static ManagerAttendanceModel toTile(ManagerTeamAttendanceItem item) {
    return ManagerAttendanceModel(
      name: (item.employeeName ?? '').trim().isEmpty
          ? 'Employee'
          : item.employeeName!.trim(),
      role: item.departmentTitle,
      team: item.locationName ?? item.currentLocation,
      checkIn: formatTime(item.checkin),
      checkOut: formatTime(item.checkout),
      status: uiStatus(item),
      photo: item.photoUrl,
    );
  }

  static List<ManagerAttendanceModel> toTiles(
    List<ManagerTeamAttendanceItem> items,
  ) {
    return items.map(toTile).toList(growable: false);
  }

  static String uiStatus(ManagerTeamAttendanceItem item) {
    if (item.isOnBreak) return 'break';
    if (item.isActive) return 'working';
    if (item.isLate) return 'late';
    if (item.isAbsent) return 'absent';
    return (item.status ?? '').trim();
  }

  static String? formatTime(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (RegExp(r'\b(am|pm)\b', caseSensitive: false).hasMatch(value)) {
      return value;
    }

    final iso = DateTime.tryParse(value);
    if (iso != null) return _ampm(iso.hour, iso.minute);

    final parts = value.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0].trim());
      final minute = int.tryParse(parts[1].trim());
      if (hour != null && minute != null) return _ampm(hour, minute);
    }
    return value;
  }

  static String _ampm(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
