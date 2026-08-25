import 'package:obecno/demo/manager_attendence_model.dart';

final List<ManagerAttendanceModel> dummyManagerAttendance = [
  /// Name + Owner + Team | check-in — check-out
  ManagerAttendanceModel(
    name: "Armando Predovic",
    role: "Owner",
    team: "Team",
    checkIn: "09:02 AM",
    checkOut: "05:07 PM",
    status: "working",
  ),

  /// Name + Manager + Team | check-in — On Break
  ManagerAttendanceModel(
    name: "Jonas Janak",
    role: "Manager",
    team: "Team",
    checkIn: "09:10 AM",
    status: "break",
  ),

  /// Name only | late check-in (red) — Late badge
  ManagerAttendanceModel(
    name: "Freddy Jast",
    checkIn: "09:40 AM",
    status: "late",
  ),

  /// Name + Team | check-in — Working badge
  ManagerAttendanceModel(
    name: "Kobe Vonrueden",
    team: "Team",
    checkIn: "09:10 AM",
    status: "working",
  ),

  /// Name | duration — On Leave badge
  ManagerAttendanceModel(
    name: "Shea Trantow",
    role: "Designer",
    checkIn: "5 Days",
    status: "leave",
  ),

  ManagerAttendanceModel(
    name: "Armin Van Buren",
    role: "Engineer",
    team: "Team",
    checkIn: "09:05 AM",
    status: "leave",
  ),

  /// Edit icon
  ManagerAttendanceModel(
    name: "Elijah Pires",
    checkIn: "09:02 AM",
    checkOut: "05:07 PM",
    editIcon: true,
  ),

  /// Warning alert
  ManagerAttendanceModel(
    name: "Elijah Pires",
    checkIn: "09:02 AM",
    checkOut: "05:07 PM",
    warning: true,
  ),

  /// Location alert
  ManagerAttendanceModel(
    name: "Elijah Pires",
    checkIn: "09:02 AM",
    checkOut: "05:07 PM",
    locationalert: true,
  ),

  /// Info alert
  ManagerAttendanceModel(
    name: "Elijah Pires",
    checkIn: "09:02 AM",
    checkOut: "05:07 PM",
    infoalert: true,
  ),

  /// Red triangle warning + red check-in / check-out
  ManagerAttendanceModel(
    name: "Elijah Pires",
    checkIn: "09:02 AM",
    checkOut: "05:07 PM",
    warningred: true,
  ),

  /// Empty state — dash
  ManagerAttendanceModel(
    name: "Jonas Janak",
  ),
];
