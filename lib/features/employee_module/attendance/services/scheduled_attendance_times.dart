import 'package:flutter/material.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';
import 'package:obecno/main.dart';

/// Default check-in / check-out / break times for an absent day, taken from
/// company (or employee) policy and any times already on that day's details.
class ScheduledAttendanceTimes {
  const ScheduledAttendanceTimes({
    required this.checkIn,
    required this.checkOut,
    required this.breakStart,
    required this.breakEnd,
    this.attendanceId,
    this.checkInDetailId,
    this.checkOutDetailId,
    this.breakStartDetailId,
    this.breakEndDetailId,
  });

  final TimeOfDay checkIn;
  final TimeOfDay checkOut;
  final TimeOfDay breakStart;
  final TimeOfDay breakEnd;
  final int? attendanceId;
  final String? checkInDetailId;
  final String? checkOutDetailId;
  final String? breakStartDetailId;
  final String? breakEndDetailId;

  static ScheduledAttendanceTimes fromPolicy(ManagerEmployeePolicy policy) {
    final checkIn = policy.checkIn;
    final checkOut = policy.checkOut;
    final breakMinutes =
        ManagerEmployeePolicy.parseMinutes(policy.breakTime) ?? 30;
    final breakStart = ReminderNotificationPlan.defaultBreakReminderTime(
      checkInTime: checkIn,
      checkOutTime: checkOut,
    );
    return ScheduledAttendanceTimes(
      checkIn: checkIn,
      checkOut: checkOut,
      breakStart: breakStart,
      breakEnd: addMinutes(breakStart, breakMinutes),
    );
  }

  static TimeOfDay addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    final wrapped = ((total % (24 * 60)) + (24 * 60)) % (24 * 60);
    return TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  static Future<ScheduledAttendanceTimes> load({
    required ApiClient apiClient,
    required DateTime day,
    int? employeeUserId,
  }) async {
    TimeOfDay? checkIn;
    TimeOfDay? checkOut;
    TimeOfDay? breakStart;
    TimeOfDay? breakEnd;
    int? attendanceId;
    String? checkInDetailId;
    String? checkOutDetailId;
    String? breakStartDetailId;
    String? breakEndDetailId;

    final policyFuture = _policyFor(employeeUserId);
    final detailsFuture = employeeUserId == null
        ? AttendanceService(apiClient).getAttendanceDetails(date: _yyyyMMdd(day))
        : null;

    if (detailsFuture != null) {
      try {
        final response = await detailsFuture;
        final data = response.data;
        attendanceId = data?.attendanceId;
        _applyDetails(
          data,
          checkIn: (t, id) {
            checkIn ??= t;
            checkInDetailId ??= id;
          },
          checkOut: (t, id) {
            checkOut ??= t;
            checkOutDetailId ??= id;
          },
          breakStart: (t, id) {
            breakStart ??= t;
            breakStartDetailId ??= id;
          },
          breakEnd: (t, id) {
            breakEnd ??= t;
            breakEndDetailId ??= id;
          },
        );
      } catch (_) {}
    }

    final policy = await policyFuture;
    final scheduled = fromPolicy(policy);
    return ScheduledAttendanceTimes(
      checkIn: checkIn ?? scheduled.checkIn,
      checkOut: checkOut ?? scheduled.checkOut,
      breakStart: breakStart ?? scheduled.breakStart,
      breakEnd: breakEnd ?? scheduled.breakEnd,
      attendanceId: attendanceId,
      checkInDetailId: checkInDetailId,
      checkOutDetailId: checkOutDetailId,
      breakStartDetailId: breakStartDetailId,
      breakEndDetailId: breakEndDetailId,
    );
  }

  static void _applyDetails(
    AttendanceDetailsData? data, {
    required void Function(TimeOfDay time, String id) checkIn,
    required void Function(TimeOfDay time, String id) checkOut,
    required void Function(TimeOfDay time, String id) breakStart,
    required void Function(TimeOfDay time, String id) breakEnd,
  }) {
    if (data == null) return;
    for (final item in data.details) {
      final time = TimeOfDay(hour: item.time.hour, minute: item.time.minute);
      switch (item.type) {
        case AttendanceHisotryEventType.checkIn:
          checkIn(time, item.id);
          break;
        case AttendanceHisotryEventType.checkOut:
          checkOut(time, item.id);
          break;
        case AttendanceHisotryEventType.breakStart:
          breakStart(time, item.id);
          break;
        case AttendanceHisotryEventType.breakEnd:
          breakEnd(time, item.id);
          break;
      }
    }
  }

  static Future<ManagerEmployeePolicy> _policyFor(int? employeeUserId) async {
    if (employeeUserId != null) {
      try {
        final response = await bindings.managerEmployeesService
            .loadEmployeePermissions(userId: employeeUserId);
        return ManagerEmployeePolicy.fromItems(response.data ?? const []);
      } catch (_) {
        return const ManagerEmployeePolicy();
      }
    }
    try {
      final items = await bindings.companyPolicyService.all();
      return ManagerEmployeePolicy.fromItems(items);
    } catch (_) {
      return const ManagerEmployeePolicy();
    }
  }

  static String _yyyyMMdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
