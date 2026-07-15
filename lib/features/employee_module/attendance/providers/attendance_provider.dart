import 'package:Obecno/core/api/base_provider.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:Obecno/features/employee_module/attendance/repositories/attendance_repository.dart';

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

  /// "July 2026" — straight from the calendar API.
  String monthLabel = '';

  /// Computed working-days / absents / late counters for [selectedMonth].
  MonthSummary? summary;

  /// UI-ready rows for `AttendanceDayTile`, latest date first.
  List<AttendanceDayRecord> records = const [];

  /// Normalized attendance rows for [selectedMonth] — the spec-mandated
  /// `attendanceList`. Kept around (rather than only exposing `records`)
  /// so a details view can pull the full check-in/out/break data for a
  /// tapped day without another round trip.
  List<AttendanceDay> attendanceList = const [];

  /// Dates the calendar API reports as having attendance this month.
  List<DateTime> calendarDates = const [];

  static DateTime _monthOnly(DateTime d) => DateTime(d.year, d.month);

  /// Human-readable error message for the current failed state, if any.
  /// (Alias of [BaseProvider.errorMessage] so this matches the field name
  /// requested in the spec — `error`.)
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

  /// Normalized record for a specific calendar day, or null if there's no
  /// attendance for it in the currently loaded month. Used to feed the
  /// existing `AttendanceDetailsSheet` when a tile is tapped.
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
