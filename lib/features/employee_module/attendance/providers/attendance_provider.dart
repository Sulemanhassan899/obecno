import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/repositories/attendance_repository.dart';

class AttendanceProvider extends BaseProvider {
  AttendanceProvider({
    required HistoryAttendanceRepository repository,
    DateTime? initialMonth,
    bool autoLoad = true,
  }) : _repository = repository,
       selectedMonth = _monthOnly(initialMonth ?? DateTime.now()) {
    if (autoLoad) loadMonth();
  }

  final HistoryAttendanceRepository _repository;

  DateTime selectedMonth;

  String monthLabel = '';

  MonthSummary? summary;

  List<AttendanceDayRecord> records = const [];

  List<AttendanceDay> attendanceList = const [];

  List<DateTime> calendarDates = const [];

  static DateTime _monthOnly(DateTime d) => DateTime(d.year, d.month);

  String? get error => errorMessage;

  Future<bool> loadMonth() {
    return safeCall<AttendanceMonthResult>(
      operationKey: 'attendance_load_month',
      request: (cancelToken) =>
          _repository.loadMonth(selectedMonth, cancelToken: cancelToken),
      onSuccess: (result) {
        monthLabel = result.monthLabel;
        summary = result.summary;
        records = result.records;
        attendanceList = result.rawDays;
        calendarDates = result.calendarDates;
      },
    );
  }

  /// Re-fetches the currently selected month.
  Future<bool> refresh() => loadMonth();

  void setMonth(DateTime date) {
    selectedMonth = _monthOnly(date);
    loadMonth();
  }

  void previousMonth() {
    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    loadMonth();
  }

  void nextMonth() {
    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
    loadMonth();
  }

  AttendanceDay? dayFor(DateTime date) {
    for (final day in attendanceList) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }
}
