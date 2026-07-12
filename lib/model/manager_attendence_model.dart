class ManagerAttendanceModel {
  final String name;
  final String? role;
  final String? team;
  final String? checkIn;
  final String? checkOut;
  final String status;
  final bool editIcon;
  final bool warning;

  const ManagerAttendanceModel({
    required this.name,
    this.role,
    this.team,
    this.checkIn,
    this.checkOut,
    this.status = "",
    this.editIcon = false,
    this.warning = false,
  });
}