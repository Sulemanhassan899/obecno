import 'package:Obecno/core/utils/demo_list.dart';
import 'package:Obecno/model/attendence_model.dart';
import 'package:flutter/cupertino.dart';

class MonthlyAttendanceController extends ChangeNotifier {
  MonthlyAttendanceController({DateTime? initialMonth})
    : selectedMonth = initialMonth ?? DateTime.now() {
    _loadMonth();
  }
  void setMonth(DateTime date) {
    selectedMonth = DateTime(date.year, date.month);
    _loadMonth();
  }

  DateTime selectedMonth;
  MonthSummary? summary;
  List<AttendanceDayRecord> records = [];
  bool isLoading = false;

  void previousMonth() {
    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    _loadMonth();
  }

  void nextMonth() {
    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
    _loadMonth();
  }

  void _loadMonth() {
    // Swap this block for an async API call when ready — set isLoading,
    // notifyListeners, await the fetch, assign results, notifyListeners.
    isLoading = true;
    notifyListeners();

    summary = MonthlyAttendanceDemoData.summaryFor(selectedMonth);
    records = MonthlyAttendanceDemoData.recordsFor(selectedMonth);

    isLoading = false;
    notifyListeners();
  }
}
