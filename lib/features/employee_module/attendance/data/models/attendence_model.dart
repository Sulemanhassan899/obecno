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
    this.hasEditedTime = false,
  });

  final int day;
  final String weekday;
  final DateTime date;
  final String? checkIn;
  final String? checkOut;
  final AttendanceDayStatus status;

  final String? weekendLabel;

  /// A check-in, check-out, or break on this date was requested, approved,
  /// or rejected.
  final bool hasEditedTime;

  AttendanceDayRecord copyWith({
    String? checkIn,
    String? checkOut,
    AttendanceDayStatus? status,
    String? weekendLabel,
    bool? hasEditedTime,
    bool clearCheckIn = false,
    bool clearCheckOut = false,
  }) {
    return AttendanceDayRecord(
      day: day,
      weekday: weekday,
      date: date,
      checkIn: clearCheckIn ? null : (checkIn ?? this.checkIn),
      checkOut: clearCheckOut ? null : (checkOut ?? this.checkOut),
      status: status ?? this.status,
      weekendLabel: weekendLabel ?? this.weekendLabel,
      hasEditedTime: hasEditedTime ?? this.hasEditedTime,
    );
  }

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
      hasEditedTime: hasEditedTime,
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

/// Tappable summary-card filters for the employee attendance month list.
enum AttendanceSummaryFilter {
  workingDays,
  absentOrLeaves,
  lateCheckIn,
  lateCheckOut,
}

/// Matches [HistoryAttendanceRepository] summary thresholds so the list
/// filter aligns with the counts shown on the summary card.
class AttendanceMonthListFilter {
  AttendanceMonthListFilter._();

  static const _lateCheckInHour = 9;
  static const _lateCheckInMinute = 15;
  static const _lateCheckOutHour = 18;
  static const _lateCheckOutMinute = 0;

  static List<AttendanceDayRecord> apply({
    required List<AttendanceDayRecord> records,
    required AttendanceSummaryFilter? filter,
  }) {
    if (filter == null) return records;

    final matched = records.where((record) {
      switch (filter) {
        case AttendanceSummaryFilter.workingDays:
          return _isWorkingDay(record);
        case AttendanceSummaryFilter.absentOrLeaves:
          return record.isOnLeave || record.isAbsent;
        case AttendanceSummaryFilter.lateCheckIn:
          return _isLateCheckIn(record);
        case AttendanceSummaryFilter.lateCheckOut:
          return _isLateCheckOut(record);
      }
    }).toList();

    matched.sort((a, b) => b.date.compareTo(a.date));
    return matched;
  }

  static bool _isWorkingDay(AttendanceDayRecord record) {
    if (record.status == AttendanceDayStatus.weekend ||
        record.status == AttendanceDayStatus.holiday ||
        record.isOnLeave ||
        record.isAbsent) {
      return false;
    }
    return true;
  }

  static bool _isLateCheckIn(AttendanceDayRecord record) {
    if (!_isWorkingDay(record)) return false;
    final time = AttendanceEditRequest.parseClockTime(
      record.checkIn ?? '',
      date: DateTime(2000, 1, 1),
    );
    if (time == null) return false;
    return time.hour > _lateCheckInHour ||
        (time.hour == _lateCheckInHour && time.minute > _lateCheckInMinute);
  }

  /// Matches summary counting: checkout before the scheduled end threshold.
  static bool _isLateCheckOut(AttendanceDayRecord record) {
    if (!_isWorkingDay(record)) return false;
    final time = AttendanceEditRequest.parseClockTime(
      record.checkOut ?? '',
      date: DateTime(2000, 1, 1),
    );
    if (time == null) return false;
    return time.hour < _lateCheckOutHour ||
        (time.hour == _lateCheckOutHour && time.minute < _lateCheckOutMinute);
  }
}
