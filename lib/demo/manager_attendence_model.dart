class ManagerAttendanceModel {
  final String name;
  final String? role;
  final String? team;
  final String? checkIn;
  final String? checkOut;
  final String status;
  final String? photo;
  final bool editIcon;
  final bool locationalert;
  final bool infoalert;
  final bool warning;
  final bool warningred;

  const ManagerAttendanceModel({
    required this.name,
    this.role,
    this.team,
    this.checkIn,
    this.checkOut,
    this.status = "",
    this.photo,
    this.editIcon = false,
    this.warning = false,
    this.locationalert = false,
    this.infoalert = false,
    this.warningred = false,
  });
}
