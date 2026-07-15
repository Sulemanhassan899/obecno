

import 'package:Obecno/core/constants/app_enums.dart';

class AttendanceDayRecord {
  const AttendanceDayRecord({
    required this.day,
    required this.weekday,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.status = AttendanceDayStatus.normal,
    this.weekendLabel,
  });

  final int day;
  final String weekday; // e.g. "Fri"
  final DateTime date;
  final String? checkIn; // e.g. "09:40 AM", null if not checked in
  final String? checkOut; // e.g. "05:12 PM", null if not checked out
  final AttendanceDayStatus status;

  /// Only used when [status] is [AttendanceDayStatus.weekend], e.g.
  /// "Sat, 10 Oct 2025 & Sun, 11 Oct 2025".
  final String? weekendLabel;
}

class MonthSummary {
  const MonthSummary({
    required this.workingDays,
    required this.totalDays,
    required this.absentOrLeaves,
    required this.lateCheckIns,
    required this.lateCheckOuts,
  });

  final int workingDays;
  final int totalDays;
  final int absentOrLeaves;
  final int lateCheckIns;
  final int lateCheckOuts;
}
