import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class TeamAttendanceMapper {
  TeamAttendanceMapper._();

  static ManagerAttendanceModel toTile(ManagerTeamAttendanceItem item) {
    return ManagerAttendanceModel(
      userId: item.userId,
      attendanceId: item.attendanceId,
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
    return statusFirst(items).map(toTile).toList(growable: false);
  }

  /// Attendance APIs often return only people who punched in. Overlay the
  /// full team so the screen can list everyone by default.
  ///
  /// When [includeUnmatchedAttendance] is false (location-scoped views), only
  /// [members] are returned — other attendance rows are dropped.
  static List<ManagerTeamAttendanceItem> mergeWithMembers({
    required List<ManagerTeamAttendanceItem> attendance,
    required List<ManagerEmployeeModel> members,
    bool includeUnmatchedAttendance = true,
  }) {
    if (members.isEmpty) {
      return includeUnmatchedAttendance ? attendance : const [];
    }

    final unused = List<ManagerTeamAttendanceItem>.from(attendance);
    final merged = <ManagerTeamAttendanceItem>[];

    for (final member in members) {
      if (member.status == ManagerEmployeeStatus.deleted) continue;

      final match = _takeMatch(unused, member);
      if (match != null) {
        merged.add(
          match.copyWith(
            userId: match.userId ?? int.tryParse(member.id),
            employeeName: (match.employeeName ?? '').trim().isEmpty
                ? member.name
                : match.employeeName,
            departmentTitle: (match.departmentTitle ?? '').trim().isEmpty
                ? (member.departmentTitle ?? member.role)
                : match.departmentTitle,
            photoUrl: (match.photoUrl == null || match.photoUrl!.isEmpty)
                ? member.photo
                : match.photoUrl,
            locationId: match.locationId ?? member.locationId,
          ),
        );
      } else {
        merged.add(
          ManagerTeamAttendanceItem(
            userId: int.tryParse(member.id),
            employeeName: member.name,
            departmentTitle: member.departmentTitle ?? member.role,
            photoUrl: member.photo,
            locationId: member.locationId,
          ),
        );
      }
    }

    if (includeUnmatchedAttendance) {
      merged.addAll(unused);
    }
    return statusFirst(merged);
  }

  static List<ManagerTeamAttendanceItem> statusFirst(
    List<ManagerTeamAttendanceItem> items,
  ) {
    final withStatus = <ManagerTeamAttendanceItem>[];
    final withoutStatus = <ManagerTeamAttendanceItem>[];
    for (final item in items) {
      if (uiStatus(item).isNotEmpty) {
        withStatus.add(item);
      } else {
        withoutStatus.add(item);
      }
    }
    return [...withStatus, ...withoutStatus];
  }

  static String uiStatus(ManagerTeamAttendanceItem item) {
    if (item.isOnBreak) return 'break';
    if (item.isLate) return 'late';
    if (item.isActive) return 'working';
    if (item.isOnLeave) return 'leave';
    return '';
  }

  static String? formatTime(String? raw, {bool withSeconds = false}) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    final ampm = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (ampm != null) {
      var hour = int.parse(ampm.group(1)!);
      final minute = int.parse(ampm.group(2)!);
      final second = int.tryParse(ampm.group(3) ?? '') ?? 0;
      final period = ampm.group(4)!.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return _ampm(hour, minute, withSeconds ? second : null);
    }

    final iso = DateTime.tryParse(value);
    if (iso != null) {
      return _ampm(iso.hour, iso.minute, withSeconds ? iso.second : null);
    }

    final parts = value.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0].trim());
      final minute = int.tryParse(parts[1].trim());
      final second = parts.length > 2 ? int.tryParse(parts[2].trim()) ?? 0 : 0;
      if (hour != null && minute != null) {
        return _ampm(hour, minute, withSeconds ? second : null);
      }
    }
    return value;
  }

  static String _ampm(int hour, int minute, [int? second]) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final time =
        '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    if (second == null) return '$time $period';
    return '$time:${second.toString().padLeft(2, '0')} $period';
  }

  static ManagerTeamAttendanceItem? _takeMatch(
    List<ManagerTeamAttendanceItem> unused,
    ManagerEmployeeModel member,
  ) {
    final id = member.id.trim();
    if (id.isNotEmpty) {
      final byId = unused.indexWhere((item) => item.userId?.toString() == id);
      if (byId >= 0) return unused.removeAt(byId);
    }

    final name = member.name.trim().toLowerCase();
    if (name.isEmpty) return null;
    final byName = unused.indexWhere(
      (item) => (item.employeeName ?? '').trim().toLowerCase() == name,
    );
    if (byName >= 0) return unused.removeAt(byName);
    return null;
  }
}
