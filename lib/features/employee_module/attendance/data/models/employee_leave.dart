import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';

/// Approved leave from GET `/employee/leaves`, used to overlay the
/// attendance month list so those dates show as On Leave.
class EmployeeLeave {
  const EmployeeLeave({
    this.id,
    this.type,
    this.status,
    this.fromDate,
    this.toDate,
  });

  final String? id;
  final String? type;
  final String? status;
  final DateTime? fromDate;
  final DateTime? toDate;

  bool get isApproved {
    final value = (status ?? '').trim().toLowerCase().replaceAll(' ', '_');
    if (value.contains('pend') ||
        value.contains('reject') ||
        value.contains('cancel') ||
        value.contains('denied') ||
        value.contains('decline')) {
      return false;
    }
    return true;
  }

  Set<DateTime> get datesInRange {
    final start = fromDate;
    if (start == null) return const {};
    final end = toDate ?? start;
    final first = start.isBefore(end) ? start : end;
    final last = start.isBefore(end) ? end : start;
    final dates = <DateTime>{};
    for (
      var day = first;
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      dates.add(DateTime(day.year, day.month, day.day));
    }
    return dates;
  }

  factory EmployeeLeave.fromJson(Map<String, dynamic> json) {
    return EmployeeLeave(
      id: _asNullableString(json['id'] ?? json['leave_id']),
      type: _asNullableString(
        json['type'] ??
            json['leave_type'] ??
            json['leave_type_title'] ??
            json['leave_type_name'] ??
            json['name'],
      ),
      status: _asNullableString(
        json['status'] ?? json['leave_status'] ?? json['status_label'],
      ),
      fromDate: _asDate(
        json['from_date'] ??
            json['date_from'] ??
            json['start_date'] ??
            json['from'] ??
            json['date'],
      ),
      toDate: _asDate(
        json['to_date'] ?? json['date_to'] ?? json['end_date'] ?? json['to'],
      ),
    );
  }

  static List<EmployeeLeave> listFrom(dynamic json) {
    return _mapsFrom(json, const [
      'leaves',
      'requests',
      'history',
      'records',
      'items',
    ]).map(EmployeeLeave.fromJson).toList(growable: false);
  }
}

class EmployeeLeaveDates {
  EmployeeLeaveDates._();

  static Set<DateTime> approvedDates(Iterable<EmployeeLeave> leaves) {
    return {
      for (final leave in leaves)
        if (leave.isApproved) ...leave.datesInRange,
    };
  }

  /// Marks matching days as leave and inserts leave-only placeholders so
  /// the month list can show On Leave even when there is no punch record.
  static List<AttendanceDay> overlay(
    List<AttendanceDay> days,
    Set<DateTime> leaveDates,
  ) {
    if (leaveDates.isEmpty) return days;

    final normalized = {
      for (final date in leaveDates) DateTime(date.year, date.month, date.day),
    };

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final result = <AttendanceDay>[
      for (final day in days)
        normalized.any((date) => sameDay(date, day.date)) && !day.isLeave
            ? day.copyWith(isLeave: true)
            : day,
    ];

    for (final date in normalized) {
      final exists = result.any((day) => sameDay(day.date, date));
      if (!exists) {
        result.add(AttendanceDay(date: date, isLeave: true));
      }
    }
    return result;
  }
}

DateTime? _asDate(dynamic raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw.toString().trim());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String? _asNullableString(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

List<Map<String, dynamic>> _mapsFrom(dynamic json, List<String> keys) {
  dynamic raw = json;
  if (json is Map) {
    final map = Map<String, dynamic>.from(json);
    raw = map['data'] ?? json;
    if (raw is Map) {
      final inner = Map<String, dynamic>.from(raw);
      for (final key in keys) {
        if (inner[key] is List) {
          raw = inner[key];
          break;
        }
      }
    }
    if (raw is! List) {
      for (final key in keys) {
        if (map[key] is List) {
          raw = map[key];
          break;
        }
      }
    }
  }
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
