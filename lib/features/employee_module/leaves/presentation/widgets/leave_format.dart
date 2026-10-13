import 'package:intl/intl.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';

class LeaveFormat {
  LeaveFormat._();

  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _dayMonthYearComma = DateFormat('d MMM, yyyy');
  static final _timeline = DateFormat('d MMM - yyyy h:mma');
  static final _weekdayFull = DateFormat('EEEE - dd MMM yyyy');
  static final _headerFull = DateFormat('d MMMM yyyy');

  static String dayMonthYear(DateTime date) => _dayMonthYear.format(date);

  static String range(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return dayMonthYear(start);
    }
    return '${_dayMonthYear.format(start)} - ${_dayMonthYearComma.format(end)}';
  }

  static String rangeWithDays(DateTime start, DateTime end, int days) {
    return '${range(start, end)} • $days ${days == 1 ? 'Day' : 'Days'}';
  }

  static String daysLabel(int days) =>
      '$days ${days == 1 ? 'Day' : 'Days'}';

  static String timelineStamp(DateTime at) => _timeline.format(at);

  static String weekdayFull(DateTime date) => _weekdayFull.format(date);

  static String headerFull(DateTime date) => _headerFull.format(date);

  static String availableLabel(int available) {
    final padded = available.toString().padLeft(2, '0');
    return '$padded Available';
  }

  static String statusLabel(LeaveRequestStatus status) {
    switch (status) {
      case LeaveRequestStatus.pending:
        return 'Pending';
      case LeaveRequestStatus.approved:
        return 'Approved';
      case LeaveRequestStatus.rejected:
        return 'Rejected';
    }
  }
}
