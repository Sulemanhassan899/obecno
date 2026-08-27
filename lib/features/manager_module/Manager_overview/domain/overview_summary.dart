import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class OverviewSummary {
  const OverviewSummary({
    required this.presentToday,
    required this.totalTeamMembers,
    required this.active,
    required this.onBreak,
    required this.lateCheckIn,
    required this.absent,
  });

  final int presentToday;
  final int totalTeamMembers;
  final int active;
  final int onBreak;
  final int lateCheckIn;
  final int absent;

  factory OverviewSummary.fromAttendance({
    required List<ManagerTeamAttendanceItem> attendance,
    required int teamMemberCount,
  }) {
    final present = attendance.where((e) => e.hasCheckIn).length;
    var total = teamMemberCount;
    if (attendance.length > total) total = attendance.length;
    if (present > total) total = present;

    return OverviewSummary(
      presentToday: present,
      totalTeamMembers: total,
      active: attendance.where((e) => e.isActive).length,
      onBreak: attendance.where((e) => e.isOnBreak).length,
      lateCheckIn: attendance.where((e) => e.isLate).length,
      absent: (total - present).clamp(0, total),
    );
  }
}

class OverviewSnapshot {
  const OverviewSnapshot({
    required this.date,
    required this.summary,
    required this.dashboard,
    required this.attendance,
  });

  final DateTime date;
  final OverviewSummary summary;
  final ManagerDashboardModel dashboard;
  final List<ManagerTeamAttendanceItem> attendance;
}
