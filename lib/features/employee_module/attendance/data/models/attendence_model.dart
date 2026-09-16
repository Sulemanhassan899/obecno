import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';

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

  bool get isOnLeave =>
      status == AttendanceDayStatus.onLeave ||
      checkIn == 'Leave' ||
      checkOut == 'Leave';

  /// Working day with no punches — the dash/minus row in the month list.
  bool get isAbsent {
    if (isOnLeave) return false;
    if (status == AttendanceDayStatus.holiday ||
        status == AttendanceDayStatus.weekend) {
      return false;
    }
    return status == AttendanceDayStatus.absent ||
        (!hasPunchTime(checkIn) && !hasPunchTime(checkOut));
  }

  static bool hasPunchTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower != 'leave' &&
        lower != 'holiday' &&
        lower != '--' &&
        !lower.startsWith('--:--');
  }

  /// True when the row has a punch that is not a 00:00–00:03 placeholder mint.
  bool get hasVisiblePunch => isRealPunch(checkIn) || isRealPunch(checkOut);

  static bool isRealPunch(String? raw) {
    if (!hasPunchTime(raw)) return false;
    final parsed = AttendanceEditRequest.parseClockTime(
      raw!,
      date: DateTime(2000, 1, 1),
    );
    if (parsed == null) return false;
    return !AttendanceEditRequest.isPlaceholderMint(parsed);
  }

  /// Pending-add overlay until the manager approves. Once the API has real
  /// punch times, keep those times on the list.
  AttendanceDayRecord overlayPendingAdd({required bool pendingAdd}) {
    if (!pendingAdd ||
        isOnLeave ||
        status == AttendanceDayStatus.holiday ||
        status == AttendanceDayStatus.weekend ||
        hasVisiblePunch) {
      return this;
    }
    return AttendanceDayRecord(
      day: day,
      weekday: weekday,
      date: date,
      status: AttendanceDayStatus.absent,
    );
  }
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
