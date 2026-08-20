import 'package:obecno/core/constants/app_enums.dart';

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
  final String weekday;
  final DateTime date;
  final String? checkIn;
  final String? checkOut;
  final AttendanceDayStatus status;

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
