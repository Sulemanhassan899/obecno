import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/attendance_duration.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';

class EmployeeAttendanceMapper {
  EmployeeAttendanceMapper._();

  static ManagerAttendanceDetailsData toDetails({
    required ManagerEmployeeAttendanceData data,
    required DateTime day,
    String? fallbackName,
    String? fallbackRole,
    String? fallbackPhoto,
    int? fallbackAttendanceId,
    int? fallbackUserId,
  }) {
    final record = dayFor(data.history, day);
    final details = record?.details ?? const [];

    final timeline =
        details
            .map(_toEvent)
            .whereType<ManagerAttendanceTimelineEvent>()
            .where((event) => _isSameDay(event.sortTime, day))
            .toList()
          ..sort((a, b) {
            final left = a.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });

    final checkInEvent = _chronological(
      timeline,
      ManagerAttendanceEventType.checkIn,
      latest: false,
    );
    final checkOutEvent = _chronological(
      timeline,
      ManagerAttendanceEventType.checkOut,
      latest: true,
    );

    final checkIn =
        checkInEvent?.timeLabel ??
        TeamAttendanceMapper.formatTime(record?.checkin);
    final checkOut =
        checkOutEvent?.timeLabel ??
        TeamAttendanceMapper.formatTime(record?.checkout);

    return ManagerAttendanceDetailsData(
      day: day,
      name: (data.employeeName ?? fallbackName ?? '').trim().isEmpty
          ? 'Employee'
          : (data.employeeName ?? fallbackName)!.trim(),
      role: fallbackRole,
      photo: data.employeePhoto ?? fallbackPhoto,
      userId: data.employeeId ?? fallbackUserId,
      attendanceId: record?.id ?? fallbackAttendanceId,
      checkIn: checkIn,
      checkOut: checkOut,
      checkInLocation: checkInEvent?.location,
      checkOutLocation: checkOutEvent?.location,
      checkInLat: checkInEvent?.lat,
      checkInLon: checkInEvent?.lon,
      checkOutLat: checkOutEvent?.lat,
      checkOutLon: checkOutEvent?.lon,
      durationLabel: formatDuration(
        hoursWorked: record?.hoursWorked,
        actualHours: data.actualHours,
        actualMinutes: data.actualMinutes,
        checkIn: checkIn,
        checkOut: checkOut,
        day: day,
      ),
      timeline: timeline,
    );
  }

  static ManagerEmployeeAttendanceDay? dayFor(
    List<ManagerEmployeeAttendanceDay> history,
    DateTime day,
  ) {
    for (final item in history) {
      final date = item.date;
      if (date == null) continue;
      if (date.year == day.year &&
          date.month == day.month &&
          date.day == day.day) {
        return item;
      }
    }
    if (history.length == 1) return history.first;
    return null;
  }

  static String? firstCheckIn(ManagerEmployeeAttendanceDay? day) {
    if (day == null) return null;
    for (final detail in day.details) {
      if (eventType(detail.type) != ManagerAttendanceEventType.checkIn) {
        continue;
      }
      final time = detail.attendanceTime ?? _clockFrom(detail.occurredAt);
      if (time != null && time.trim().isNotEmpty) return time;
    }
    if ((day.checkin ?? '').trim().isNotEmpty) return day.checkin;
    return null;
  }

  static String? lastCheckOut(ManagerEmployeeAttendanceDay? day) {
    if (day == null) return null;
    String? found;
    for (final detail in day.details) {
      if (eventType(detail.type) != ManagerAttendanceEventType.checkOut) {
        continue;
      }
      final time = detail.attendanceTime ?? _clockFrom(detail.occurredAt);
      if (time != null && time.trim().isNotEmpty) found = time;
    }
    if (found != null) return found;
    if ((day.checkout ?? '').trim().isNotEmpty) return day.checkout;
    return null;
  }

  static String? _clockFrom(DateTime? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  static String formatDuration({
    String? hoursWorked,
    String? actualHours,
    int? actualMinutes,
    String? checkIn,
    String? checkOut,
    DateTime? day,
    DateTime? now,
  }) {
    if (day != null && (checkIn != null || checkOut != null)) {
      return AttendanceDuration.label(
        day: day,
        checkIn: checkIn,
        checkOut: checkOut,
        hoursWorked: hoursWorked,
        actualHours: actualHours,
        actualMinutes: actualMinutes,
        now: now,
      );
    }

    final fromWorked = AttendanceDuration.fromClock(hoursWorked);
    if (fromWorked != null && fromWorked != '0h 00m') return fromWorked;

    final fromActual = AttendanceDuration.fromClock(actualHours);
    if (fromActual != null && fromActual != '0h 00m') return fromActual;

    if (actualMinutes != null && actualMinutes > 0) {
      return AttendanceDuration.format(Duration(minutes: actualMinutes));
    }

    return fromWorked ?? fromActual ?? '0h 00m';
  }

  static ManagerAttendanceTimelineEvent? _toEvent(
    ManagerEmployeeAttendanceDetail detail,
  ) {
    final type = eventType(detail.type);
    if (type == null) return null;

    final time = detail.occurredAt ?? _timeFrom(detail.attendanceTime);
    final timeLabel = time != null
        ? TeamAttendanceMapper.formatTime(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          )
        : TeamAttendanceMapper.formatTime(detail.attendanceTime);

    if (timeLabel == null || timeLabel.isEmpty) return null;

    return ManagerAttendanceTimelineEvent(
      type: type,
      timeLabel: timeLabel,
      id: detail.id?.toString(),
      sortTime: time ?? DateTime.fromMillisecondsSinceEpoch(0),
      location: detail.currentLocation,
      lat: detail.lat,
      lon: detail.lon,
    );
  }

  static ManagerAttendanceEventType? eventType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'check in':
      case 'checkin':
      case 'check-in':
      case 'check_in':
        return ManagerAttendanceEventType.checkIn;
      case 'check out':
      case 'checkout':
      case 'check-out':
      case 'check_out':
        return ManagerAttendanceEventType.checkOut;
      case 'break out':
      case 'breakout':
      case 'break start':
        return ManagerAttendanceEventType.breakStart;
      case 'break in':
      case 'breakin':
      case 'break end':
        return ManagerAttendanceEventType.breakEnd;
      default:
        return null;
    }
  }

  static ManagerAttendanceTimelineEvent? _chronological(
    List<ManagerAttendanceTimelineEvent> events,
    ManagerAttendanceEventType type, {
    required bool latest,
  }) {
    ManagerAttendanceTimelineEvent? found;
    for (final event in events) {
      if (event.type != type) continue;
      if (found == null) {
        found = event;
        continue;
      }
      final current = event.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final selected = found.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (latest ? current.isAfter(selected) : current.isBefore(selected)) {
        found = event;
      }
    }
    return found;
  }

  static DateTime? _timeFrom(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    final second = parts.length > 2 ? int.tryParse(parts[2].trim()) ?? 0 : 0;
    if (hour == null || minute == null) return null;
    return DateTime(1970, 1, 1, hour, minute, second);
  }

  static bool _isSameDay(DateTime? time, DateTime day) {
    if (time == null) return true;
    if (time.millisecondsSinceEpoch == 0 || time.year <= 1970) return true;
    return time.year == day.year &&
        time.month == day.month &&
        time.day == day.day;
  }
}
