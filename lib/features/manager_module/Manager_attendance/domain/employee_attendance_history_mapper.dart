import 'package:flutter/material.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';

class ManagerEmployeeHistoryMonth {
  const ManagerEmployeeHistoryMonth({
    required this.summary,
    required this.records,
  });

  final MonthSummary summary;
  final List<AttendanceDayRecord> records;
}

class ManagerEmployeeHistoryMapper {
  ManagerEmployeeHistoryMapper._();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static ManagerEmployeeHistoryMonth build({
    required DateTime month,
    required List<ManagerEmployeeAttendanceDay> history,
    Set<int> workingWeekdays = const {1, 2, 3, 4, 5},
    List<HolidayInfo> holidays = const [],
    TimeOfDay? scheduledCheckIn,
    int graceMinutes = 0,
    TimeOfDay? scheduledCheckOut,
    DateTime? joiningDate,
  }) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final today = DateTime.now();
    final lastDay =
        DateTime(today.year, today.month, today.day).isBefore(monthEnd)
        ? (month.year == today.year && month.month == today.month
              ? DateTime(today.year, today.month, today.day)
              : monthEnd)
        : monthEnd;

    var loopStart = monthStart;
    if (joiningDate != null) {
      final join = DateTime(
        joiningDate.year,
        joiningDate.month,
        joiningDate.day,
      );
      if (loopStart.isBefore(join)) loopStart = join;
    }

    if (lastDay.isBefore(loopStart)) {
      return const ManagerEmployeeHistoryMonth(
        summary: MonthSummary(
          workingDays: 0,
          totalDays: 0,
          absentOrLeaves: 0,
          lateCheckIns: 0,
          lateCheckOuts: 0,
        ),
        records: [],
      );
    }

    final byDate = <String, ManagerEmployeeAttendanceDay>{};
    final attendanceDates = <DateTime>{};
    final leaveDates = <DateTime>{};
    final mergedHolidays = [...holidays];
    for (final day in history) {
      final date = day.date;
      if (date == null) continue;
      final dateOnly = DateTime(date.year, date.month, date.day);
      byDate[_key(date)] = day;
      if ((day.checkin ?? '').trim().isNotEmpty ||
          (day.checkout ?? '').trim().isNotEmpty ||
          day.details.isNotEmpty) {
        attendanceDates.add(dateOnly);
      }
      if (day.isHoliday) {
        mergedHolidays.add(
          HolidayInfo(
            date: dateOnly,
            name: (day.holidayName ?? '').trim().isEmpty
                ? 'Public Holiday'
                : day.holidayName!.trim(),
          ),
        );
      }
      if (day.isLeave) {
        leaveDates.add(dateOnly);
      }
    }

    final rawRecords = <AttendanceDayRecord>[];
    var workingDays = 0;
    var totalWorking = 0;
    var absent = 0;
    var lateIns = 0;
    var lateOuts = 0;

    for (
      var day = loopStart;
      !day.isAfter(lastDay);
      day = day.add(const Duration(days: 1))
    ) {
      final classification = DayClassificationEngine.classifyDay(
        date: day,
        workingWeekdays: workingWeekdays,
        attendanceDates: attendanceDates,
        holidays: mergedHolidays,
        leaveDates: leaveDates,
      );

      final punched = byDate[_key(day)];
      final hasPunch =
          punched != null &&
          ((punched.checkin ?? '').trim().isNotEmpty ||
              (punched.checkout ?? '').trim().isNotEmpty ||
              punched.details.isNotEmpty);

      String? checkIn;
      String? checkOut;
      AttendanceDayStatus status;
      String? weekendLabel;

      if (hasPunch && classification.type != DayCardType.holiday) {
        checkIn =
            TeamAttendanceMapper.formatTime(punched.checkin) ??
            _firstDetailTime(punched, const ['check in', 'checkin']);
        checkOut =
            TeamAttendanceMapper.formatTime(punched.checkout) ??
            _firstDetailTime(punched, const ['check out', 'checkout']);
        status = (checkOut == null || checkOut.isEmpty)
            ? AttendanceDayStatus.missingCheckOut
            : AttendanceDayStatus.normal;
        totalWorking += 1;
        workingDays += 1;
        if (_isLateIn(
          punched.checkin ?? checkIn,
          scheduledCheckIn,
          graceMinutes,
        )) {
          lateIns += 1;
        }
        if (_isLateOut(punched.checkout ?? checkOut, scheduledCheckOut)) {
          lateOuts += 1;
        }
      } else {
        switch (classification.type) {
          case DayCardType.holiday:
            status = AttendanceDayStatus.holiday;
            weekendLabel = classification.holidayName ?? 'Public Holiday';
            break;
          case DayCardType.weekend:
            status = AttendanceDayStatus.weekend;
            break;
          case DayCardType.onLeave:
            status = AttendanceDayStatus.onLeave;
            checkIn = 'Leave';
            checkOut = 'Leave';
            totalWorking += 1;
            absent += 1;
            break;
          case DayCardType.absent:
            status = AttendanceDayStatus.absent;
            totalWorking += 1;
            absent += 1;
            break;
          case DayCardType.worked:
            checkIn = TeamAttendanceMapper.formatTime(punched?.checkin);
            checkOut = TeamAttendanceMapper.formatTime(punched?.checkout);
            status = (checkOut == null || checkOut.isEmpty)
                ? AttendanceDayStatus.missingCheckOut
                : AttendanceDayStatus.normal;
            totalWorking += 1;
            workingDays += 1;
            if (_isLateIn(punched?.checkin, scheduledCheckIn, graceMinutes)) {
              lateIns += 1;
            }
            if (_isLateOut(punched?.checkout, scheduledCheckOut)) {
              lateOuts += 1;
            }
            break;
        }
      }

      rawRecords.add(
        AttendanceDayRecord(
          day: day.day,
          weekday: _weekdays[day.weekday - 1],
          date: day,
          checkIn: checkIn,
          checkOut: checkOut,
          status: status,
          weekendLabel: weekendLabel,
        ),
      );
    }

    return ManagerEmployeeHistoryMonth(
      summary: MonthSummary(
        workingDays: workingDays,
        totalDays: totalWorking,
        absentOrLeaves: absent,
        lateCheckIns: lateIns,
        lateCheckOuts: lateOuts,
      ),
      records: AttendanceListGrouping.groupConsecutiveWeekends(rawRecords),
    );
  }

  static String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String? _firstDetailTime(
    ManagerEmployeeAttendanceDay day,
    List<String> types,
  ) {
    for (final detail in day.details) {
      final type = detail.type.trim().toLowerCase();
      if (!types.contains(type)) continue;
      final formatted = TeamAttendanceMapper.formatTime(detail.attendanceTime);
      if (formatted != null && formatted.isNotEmpty) return formatted;
    }
    return null;
  }

  static bool _isLateIn(String? raw, TimeOfDay? scheduled, int graceMinutes) {
    final punched = _parseMinutes(raw);
    final start = scheduled == null
        ? null
        : scheduled.hour * 60 + scheduled.minute + graceMinutes;
    if (punched == null || start == null) return false;
    return punched > start;
  }

  static bool _isLateOut(String? raw, TimeOfDay? scheduled) {
    final punched = _parseMinutes(raw);
    final end = scheduled == null
        ? null
        : scheduled.hour * 60 + scheduled.minute;
    if (punched == null || end == null) return false;
    return punched > end;
  }

  static int? _parseMinutes(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final ampm = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (ampm != null) {
      var hour = int.parse(ampm.group(1)!);
      final minute = int.parse(ampm.group(2)!);
      final period = ampm.group(4)!.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    }
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
}
