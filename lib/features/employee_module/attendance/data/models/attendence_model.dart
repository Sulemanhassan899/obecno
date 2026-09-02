import 'package:obecno/core/constants/app_enums.dart';

/// Groups consecutive weekend rows. Holidays stay as individual cards.
class AttendanceListGrouping {
  AttendanceListGrouping._();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static List<AttendanceDayRecord> groupConsecutiveWeekends(
    List<AttendanceDayRecord> ascending,
  ) {
    final result = <AttendanceDayRecord>[];
    var run = <AttendanceDayRecord>[];

    void flush() {
      if (run.isEmpty) return;
      final start = run.first.date;
      final end = run.last.date;
      result.add(
        AttendanceDayRecord(
          day: end.day,
          weekday: '',
          date: end,
          status: AttendanceDayStatus.weekend,
          weekendLabel: 'Weekend, ${_formatDate(start)} - ${_formatDate(end)}',
        ),
      );
      run = [];
    }

    for (final record in ascending) {
      if (record.status == AttendanceDayStatus.weekend) {
        run.add(record);
      } else {
        flush();
        result.add(record);
      }
    }
    flush();
    return result.reversed.toList();
  }

  static String _formatDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';
}

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
