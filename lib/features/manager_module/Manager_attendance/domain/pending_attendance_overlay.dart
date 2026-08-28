import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class PendingAttendanceSave {
  const PendingAttendanceSave({
    required this.userId,
    required this.employeeName,
    required this.day,
    required this.checkIn,
    required this.checkOut,
  });

  final int? userId;
  final String? employeeName;
  final DateTime day;
  final String? checkIn;
  final String? checkOut;

  @override
  String toString() =>
      '$employeeName/$userId day=$day in=$checkIn out=$checkOut';
}

class PendingAttendanceOverlay {
  PendingAttendanceOverlay._();

  static bool sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool matches(
    ManagerTeamAttendanceItem item,
    PendingAttendanceSave pending,
  ) {
    if (pending.userId != null && item.userId != null) {
      return item.userId == pending.userId;
    }
    final name = (pending.employeeName ?? '').trim().toLowerCase();
    if (name.isEmpty) return false;
    return (item.employeeName ?? '').trim().toLowerCase() == name;
  }

  static List<ManagerTeamAttendanceItem> apply({
    required List<ManagerTeamAttendanceItem> items,
    required Iterable<PendingAttendanceSave> pending,
    required DateTime selectedDate,
  }) {
    var next = List<ManagerTeamAttendanceItem>.from(items);
    for (final save in pending) {
      if (!sameDay(save.day, selectedDate)) continue;
      var found = false;
      next = next.map((item) {
        if (!matches(item, save)) return item;
        found = true;
        return item.copyWith(
          checkin: save.checkIn ?? item.checkin,
          checkout: save.checkOut ?? item.checkout,
          isOpen: save.checkOut != null ? false : item.isOpen,
          isLate: save.checkIn != null ? false : item.isLate,
        );
      }).toList();
      if (!found && save.userId != null) {
        next = [
          ...next,
          ManagerTeamAttendanceItem(
            userId: save.userId,
            employeeName: save.employeeName,
            checkin: save.checkIn,
            checkout: save.checkOut,
            isOpen: save.checkOut == null,
          ),
        ];
      }
    }
    return next;
  }

  static bool matchesEmployee(
    PendingAttendanceSave pending, {
    required int? userId,
    required String? employeeName,
  }) {
    if (pending.userId != null && userId != null) {
      return pending.userId == userId;
    }
    final name = (pending.employeeName ?? '').trim().toLowerCase();
    final other = (employeeName ?? '').trim().toLowerCase();
    if (name.isEmpty || other.isEmpty) return false;
    return name == other;
  }

  static List<ManagerEmployeeAttendanceDay> applyToHistory({
    required List<ManagerEmployeeAttendanceDay> history,
    required Iterable<PendingAttendanceSave> pending,
    int? userId,
    String? employeeName,
  }) {
    final next = List<ManagerEmployeeAttendanceDay>.from(history);
    for (final save in pending) {
      if (!matchesEmployee(save, userId: userId, employeeName: employeeName)) {
        continue;
      }
      final day = DateTime(save.day.year, save.day.month, save.day.day);
      final index = next.indexWhere(
        (item) => item.date != null && sameDay(item.date!, day),
      );
      if (index >= 0) {
        next[index] = next[index].copyWith(
          checkin: save.checkIn ?? next[index].checkin,
          checkout: save.checkOut ?? next[index].checkout,
          isOpen: save.checkOut != null ? false : next[index].isOpen,
        );
      } else {
        next.add(
          ManagerEmployeeAttendanceDay(
            date: day,
            checkin: save.checkIn,
            checkout: save.checkOut,
            isOpen: save.checkOut == null,
          ),
        );
      }
    }
    return next;
  }
}
