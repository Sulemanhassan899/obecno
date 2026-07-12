

import 'package:Obecno/core/constants/app_enums.dart';


class OverViewMonthSummary {
  const OverViewMonthSummary({
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
