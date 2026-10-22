import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/repositories/manager_attendance_repository.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/repositories/manager_employees_repository.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/repositories/manager_overview_repository.dart';

class ManagerAttendanceService {
  ManagerAttendanceService(
    this._repository, {
    ManagerEmployeesRepository? employeesRepository,
    ManagerOverviewRepository? overviewRepository,
    String? Function()? currentUserIdProvider,
  }) : _employeesRepository = employeesRepository,
       _overviewRepository = overviewRepository,
       _currentUserIdProvider = currentUserIdProvider;

  final ManagerAttendanceRepository _repository;
  final ManagerEmployeesRepository? _employeesRepository;
  final ManagerOverviewRepository? _overviewRepository;
  final String? Function()? _currentUserIdProvider;

  String? get currentUserId {
    final raw = _currentUserIdProvider?.call()?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  Future<ApiResponse<ManagerTeamAttendanceData>> loadTeamAttendance({
    required DateTime date,
    String? search,
    ApiCancelToken? cancelToken,
  }) async {
    final attendanceFuture = _repository.getTeamAttendance(
      date: _yyyyMMdd(date),
      search: search,
      cancelToken: cancelToken,
    );
    final membersFuture = _loadMembers(cancelToken);
    final liveFuture = _isToday(date)
        ? _liveToday(cancelToken)
        : Future.value(const <ManagerTeamAttendanceItem>[]);

    final attendanceResponse = await attendanceFuture;
    final members = await membersFuture;
    final live = await liveFuture;

    // Team-attendance often omits people who never punched (common for
    // employees with no office). Always overlay the full directory first.
    final punchRows = attendanceResponse.success && attendanceResponse.data != null
        ? attendanceResponse.data!.attendance
        : const <ManagerTeamAttendanceItem>[];

    if (punchRows.isEmpty && members.isEmpty) {
      return attendanceResponse.success && attendanceResponse.data != null
          ? attendanceResponse
          : ApiResponse.failure(
              attendanceResponse.message ?? 'Failed to load attendance.',
              statusCode: attendanceResponse.statusCode,
            );
    }

    final merged = TeamAttendanceMapper.mergeWithMembers(
      attendance: punchRows,
      members: members,
    );
    final withLive = TeamAttendanceMapper.overlayLive(
      items: merged,
      live: live,
    );
    // List load: seed leadership rows only. Per-employee punch hydration is
    // deferred to the detail sheet so we do not fire N+1 attendance calls
    // (slow load + 401/403 session storms) on every open.
    final withOwner = await withOwnerAttendance(
      items: withLive,
      members: members,
      date: date,
      hydrateMissingPunches: false,
    );
    final attendance = await _stampLeavesForDate(
      attendance: withOwner,
      date: date,
      cancelToken: cancelToken,
    );

    final payload = attendanceResponse.data;
    return ApiResponse.success(
      ManagerTeamAttendanceData(
        date: payload?.date,
        departmentId: payload?.departmentId,
        filter: payload?.filter,
        search: payload?.search ?? search,
        total: attendance.length,
        attendance: attendance,
        members: members,
      ),
      message: attendanceResponse.message,
      statusCode: attendanceResponse.statusCode,
    );
  }

  /// Overlay team-leaves onto attendance so On Leave filter works (incl. weekends).
  ///
  /// Past dates often omit leave from team-attendance punches, so we resolve
  /// approved leaves the same way Overview does (day `date` / from-to / month
  /// / no-status fallbacks) instead of only two approved range queries.
  Future<List<ManagerTeamAttendanceItem>> _stampLeavesForDate({
    required List<ManagerTeamAttendanceItem> attendance,
    required DateTime date,
    ApiCancelToken? cancelToken,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final nameToUserId = <String, int>{};
    for (final item in attendance) {
      final id = item.userId;
      final name = item.employeeName?.trim().toLowerCase();
      if (id != null && name != null && name.isNotEmpty) {
        nameToUserId.putIfAbsent(name, () => id);
      }
    }

    final leaveByUser = <int, ManagerTeamLeaveItem>{};
    final rejectedUserIds = <int>{};
    void consider(
      ManagerTeamLeaveItem leave, {
      required bool assumeApprovedQuery,
      required bool allowMissingDates,
    }) {
      final hasDates =
          (leave.dateFrom ?? '').trim().isNotEmpty ||
          (leave.dateTo ?? '').trim().isNotEmpty;
      if (hasDates) {
        if (!leave.coversDay(day)) return;
      } else if (!allowMissingDates) {
        return;
      }
      final userId = leave.userId ??
          nameToUserId[leave.employeeName?.trim().toLowerCase() ?? ''];
      if (userId == null) return;
      if (leave.isRejectedLeave) {
        rejectedUserIds.add(userId);
        return;
      }
      if (!leave.countsAsOnLeaveOrBlank(
        assumeApprovedQuery: assumeApprovedQuery,
      )) {
        return;
      }
      leaveByUser.putIfAbsent(userId, () => leave);
    }

    final overview = _overviewRepository;
    if (overview != null) {
      final dayKey = _yyyyMMdd(day);
      final monthStart = DateTime(day.year, day.month, 1);
      final monthEnd = DateTime(day.year, day.month + 1, 0);
      final monthFrom = _yyyyMMdd(monthStart);
      final monthTo = _yyyyMMdd(monthEnd);
      try {
        Future<List<ManagerTeamLeaveItem>> pull({
          String? status,
          String? dateFrom,
          String? dateTo,
          String? date,
        }) async {
          final res = await overview.getTeamLeaves(
            status: status,
            dateFrom: dateFrom,
            dateTo: dateTo,
            date: date,
            cancelToken: cancelToken,
          );
          return res.data ?? const [];
        }

        void ingest(
          List<ManagerTeamLeaveItem> batch, {
          required bool assumeApprovedQuery,
          required bool allowMissingDates,
        }) {
          for (final leave in batch) {
            consider(
              leave,
              assumeApprovedQuery: assumeApprovedQuery,
              allowMissingDates: allowMissingDates,
            );
          }
        }

        // Contract: at most two queries — day range, then month range.
        final dayBatch = await pull(
          status: 'approved',
          dateFrom: dayKey,
          dateTo: dayKey,
        );
        ingest(dayBatch, assumeApprovedQuery: true, allowMissingDates: true);

        if (leaveByUser.isEmpty) {
          final monthBatch = await pull(
            status: 'approved',
            dateFrom: monthFrom,
            dateTo: monthTo,
          );
          ingest(
            monthBatch,
            assumeApprovedQuery: true,
            allowMissingDates: false,
          );
        }
      } catch (_) {
        // Leave overlay is best-effort; list still shows punch/directory rows.
      }
    }

    if (leaveByUser.isEmpty && rejectedUserIds.isEmpty) return attendance;

    final result = <ManagerTeamAttendanceItem>[];
    final seen = <int>{};
    for (final item in attendance) {
      final userId = item.userId;
      if (userId != null && leaveByUser.containsKey(userId)) {
        seen.add(userId);
        result.add(
          item.isOnLeave
              ? item
              : item.copyWith(
                  status: 'leave',
                  statusLabel: 'On Leave',
                  isOpen: false,
                ),
        );
      } else if (userId != null &&
          rejectedUserIds.contains(userId) &&
          item.isOnLeave &&
          !item.hasCheckIn) {
        // Rejected leave must not keep an On Leave badge — show Absent.
        result.add(
          item.copyWith(status: 'absent', statusLabel: 'Absent', isOpen: false),
        );
      } else {
        result.add(item);
      }
    }
    for (final entry in leaveByUser.entries) {
      if (seen.contains(entry.key)) continue;
      final leave = entry.value;
      result.add(
        ManagerTeamAttendanceItem(
          userId: entry.key,
          employeeName: leave.employeeName ?? 'Employee',
          status: 'leave',
          statusLabel: leave.leaveType ?? 'On Leave',
        ),
      );
    }
    return result;
  }

  Future<ApiResponse<ManagerEmployeeAttendanceData>> loadEmployeeAttendance({
    required int userId,
    required DateTime date,
    ApiCancelToken? cancelToken,
  }) async {
    try {
      final details = await _repository.getEmployeeDayDetails(
        userId: userId,
        date: _yyyyMMdd(date),
        cancelToken: cancelToken,
      );
      if (details.success &&
          details.data != null &&
          details.data!.history.isNotEmpty) {
        return details;
      }
    } catch (_) {}
    return loadEmployeeAttendanceRange(
      userId: userId,
      from: date,
      to: date,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerEmployeeAttendanceData>>
  loadEmployeeAttendanceRange({
    required int userId,
    required DateTime from,
    required DateTime to,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeAttendance(
      userId: userId,
      dateFrom: _yyyyMMdd(from),
      dateTo: _yyyyMMdd(to),
      cancelToken: cancelToken,
    );
  }

  /// Company holiday for [date], if any (used for the attendance holiday screen).
  Future<HolidayInfo?> holidayForDate(
    DateTime date, {
    ApiCancelToken? cancelToken,
  }) async {
    final month =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}';
    final response = await _repository.getCompanyHolidays(
      month: month,
      cancelToken: cancelToken,
    );
    if (!response.success || response.data == null) return null;
    final day = DateTime(date.year, date.month, date.day);
    for (final holiday in response.data!) {
      final h = DateTime(
        holiday.date.year,
        holiday.date.month,
        holiday.date.day,
      );
      if (h == day) return holiday;
    }
    return null;
  }

  Future<ApiResponse<String>> saveEmployeeAttendance({
    required int? attendanceId,
    required int? userId,
    required DateTime day,
    required String deviceDetails,
    required double lat,
    required double lon,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
    String? checkInDetailId,
    String? checkOutDetailId,
    String? breakStartDetailId,
    String? breakEndDetailId,
    List<Map<String, dynamic>> additionalEvents = const [],
    required List<AttendanceChangeRequestPayload> changes,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.saveEmployeeAttendance(
      attendanceId: attendanceId,
      userId: userId,
      date: _yyyyMMdd(day),
      deviceDetails: deviceDetails,
      lat: lat,
      lon: lon,
      checkIn: checkIn,
      checkOut: checkOut,
      breakStart: breakStart,
      breakEnd: breakEnd,
      checkInDetailId: checkInDetailId,
      checkOutDetailId: checkOutDetailId,
      breakStartDetailId: breakStartDetailId,
      breakEndDetailId: breakEndDetailId,
      additionalEvents: additionalEvents,
      changes: changes,
      cancelToken: cancelToken,
    );
  }

  Future<String?> loadEmployeePhoto({
    required int userId,
    ApiCancelToken? cancelToken,
  }) async {
    final repo = _employeesRepository;
    if (repo == null) return null;
    final userKey = userId.toString();

    try {
      final profile = await repo.getEmployeeProfile(
        userId: userId,
        cancelToken: cancelToken,
      );
      final photo = profile.data?.photo;
      if (photo != null && photo.isNotEmpty) return photo;
    } catch (_) {}

    try {
      final response = await repo.getEmployees(cancelToken: cancelToken);
      final photo = _photoForUser(response.data?.members, userKey);
      if (photo != null) return photo;
    } catch (_) {}

    try {
      final response = await repo.getTeamMembers(cancelToken: cancelToken);
      return _photoForUser(response.data?.members, userKey);
    } catch (_) {
      return null;
    }
  }

  static String? _photoForUser(
    List<ManagerEmployeeModel>? members,
    String userId,
  ) {
    if (members == null) return null;
    for (final member in members) {
      if (member.id != userId) continue;
      final photo = member.photo;
      if (photo != null && photo.isNotEmpty) return photo;
    }
    return null;
  }

  static String yyyyMMdd(DateTime date) => _yyyyMMdd(date);

  static String _yyyyMMdd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<List<ManagerEmployeeModel>> _loadMembers(
    ApiCancelToken? cancelToken,
  ) async {
    final repo = _employeesRepository;
    if (repo == null) return const [];
    try {
      final employeesFuture = repo.getEmployees(
        pageSize: 200,
        cancelToken: cancelToken,
      );
      final teamFuture = repo.getTeamMembers(
        pageSize: 200,
        cancelToken: cancelToken,
      );
      final employees = await employeesFuture;
      final team = await teamFuture;

      final byId = <String, ManagerEmployeeModel>{};
      void addAll(List<ManagerEmployeeModel> list) {
        for (final member in list) {
          final id = member.id.trim();
          if (id.isEmpty) continue;
          byId.putIfAbsent(id, () => member);
        }
      }

      if (employees.success && employees.data != null) {
        addAll(employees.data!.members);
      }
      if (team.success && team.data != null) {
        addAll(team.data!.members);
      }
      return byId.values.toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ManagerTeamAttendanceItem>> _liveToday(
    ApiCancelToken? cancelToken,
  ) async {
    final repo = _overviewRepository;
    if (repo == null) return const [];
    try {
      final response = await repo.getDashboard(cancelToken: cancelToken);
      if (!response.success || response.data == null) return const [];
      return response.data!.teamAttendanceToday;
    } catch (_) {
      return const [];
    }
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Ensures owners/managers are listed and backfills punches for anyone whose
  /// team-attendance / live overlay row is missing check-in status. Detail
  /// sheets already use the per-employee API; the list must do the same when
  /// the bulk endpoints omit live status (common with multiple managers).
  ///
  /// Pass [hydrateMissingPunches]: false for list loads (bulk APIs only).
  Future<List<ManagerTeamAttendanceItem>> withOwnerAttendance({
    required List<ManagerTeamAttendanceItem> items,
    required List<ManagerEmployeeModel> members,
    required DateTime date,
    bool hydrateMissingPunches = true,
  }) async {
    final seeded = _ensureLeadershipRows(items, members);
    if (!hydrateMissingPunches) {
      String? currentName;
      final id = currentUserId;
      if (id != null) {
        for (final member in members) {
          if (member.id == id) {
            currentName = member.name;
            break;
          }
        }
      }
      return TeamAttendanceMapper.statusFirst(
        seeded,
        currentUserId: id,
        currentUserName: currentName,
      );
    }
    return _hydrateMissingPunches(items: seeded, members: members, date: date);
  }

  List<ManagerTeamAttendanceItem> _ensureLeadershipRows(
    List<ManagerTeamAttendanceItem> items,
    List<ManagerEmployeeModel> members,
  ) {
    final next = [...items];
    final currentId = int.tryParse(currentUserId ?? '');

    void addIfMissing(ManagerEmployeeModel member) {
      final id = member.userId;
      final exists = next.any((item) {
        if (id != null && item.userId == id) return true;
        return (item.employeeName ?? '').trim().toLowerCase() ==
            member.name.trim().toLowerCase();
      });
      if (exists) return;
      next.add(
        ManagerTeamAttendanceItem(
          userId: id,
          employeeName: member.name,
          departmentTitle: member.departmentTitle ?? member.role,
          photoUrl: member.photo,
          locationId: member.locationId,
          locationName: member.locationName,
        ),
      );
    }

    for (final member in members) {
      if (_isOwnerOrManager(member) ||
          (currentId != null && member.userId == currentId)) {
        addIfMissing(member);
      }
    }

    if (currentId != null &&
        !next.any((item) => item.userId == currentId) &&
        !next.any((item) => _isOwnerName(item.employeeName))) {
      next.add(ManagerTeamAttendanceItem(userId: currentId));
    }
    return next;
  }

  Future<List<ManagerTeamAttendanceItem>> _hydrateMissingPunches({
    required List<ManagerTeamAttendanceItem> items,
    required List<ManagerEmployeeModel> members,
    required DateTime date,
  }) async {
    final next = [...items];
    final tasks = <Future<void>>[];

    for (var i = 0; i < next.length; i++) {
      final item = next[i];
      final userId = item.userId ?? _userIdForName(members, item.employeeName);
      if (userId == null) continue;

      final needsPunch = !item.hasCheckIn;
      final needsLocation =
          (item.locationId == null || item.locationId!.trim().isEmpty) &&
          (item.locationName == null || item.locationName!.trim().isEmpty) &&
          (item.currentLocation == null ||
              item.currentLocation!.trim().isEmpty);

      // Already has punches — only refill location for leadership rows.
      if (!needsPunch) {
        if (!needsLocation ||
            (!_isLeadershipName(item.employeeName) &&
                !_isLeadershipUser(members, userId))) {
          continue;
        }
      }

      final index = i;
      tasks.add(() async {
        try {
          final response = await loadEmployeeAttendance(
            userId: userId,
            date: date,
          );
          if (!response.success || response.data == null) return;
          final day = EmployeeAttendanceMapper.dayFor(
            response.data!.history,
            date,
          );
          final checkin = EmployeeAttendanceMapper.firstCheckIn(day);
          final isOpen = EmployeeAttendanceMapper.isSessionOpen(day);
          final onBreak = EmployeeAttendanceMapper.isOnBreak(day);
          final checkout = EmployeeAttendanceMapper.liveCheckOut(day);
          final punchLocation = _locationFromDay(day);
          if ((checkin == null || checkin.trim().isEmpty) &&
              (checkout == null || checkout.trim().isEmpty) &&
              punchLocation == null &&
              !onBreak &&
              !isOpen &&
              !needsPunch &&
              !needsLocation) {
            return;
          }
          final hasCheckin =
              (checkin ?? next[index].checkin)?.trim().isNotEmpty == true;
          final previous = next[index];
          final previousLate = previous.isLate ||
              _statusLooksLate(previous.status) ||
              _statusLooksLate(previous.statusLabel);
          final onLeave = day?.isLeave == true && !hasCheckin;
          next[index] = previous.copyWith(
            userId: userId,
            attendanceId: day?.id ?? previous.attendanceId,
            employeeName: (previous.employeeName ?? '').trim().isEmpty
                ? (response.data!.employeeName ?? previous.employeeName)
                : previous.employeeName,
            checkin: checkin ?? previous.checkin,
            checkout: isOpen || onBreak
                ? ''
                : (checkout ?? previous.checkout),
            isOnBreak: onBreak,
            // Open session → live badge; never drop a prior late flag.
            // Leave beats working when attendance day is flagged is_leave.
            status: onBreak
                ? 'break'
                : (onLeave
                      ? 'leave'
                      : (isOpen ? 'working' : previous.status)),
            isLate: previousLate,
            isEdited: previous.isEdited || (day?.isEdited ?? false),
            isOutsideLocation: previous.isOutsideLocation,
            isOpen: onLeave ? false : (isOpen || onBreak),
            locationId: previous.locationId ?? punchLocation?.$1,
            locationName: previous.locationName ?? punchLocation?.$2,
            currentLocation:
                previous.currentLocation ??
                punchLocation?.$3 ??
                day?.currentLocation,
            lat: day?.lat ?? previous.lat,
            lon: day?.lon ?? previous.lon,
          );
        } catch (_) {}
      }());
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
    String? currentName;
    final id = currentUserId;
    if (id != null) {
      for (final member in members) {
        if (member.id == id) {
          currentName = member.name;
          break;
        }
      }
    }
    return TeamAttendanceMapper.statusFirst(
      next,
      currentUserId: id,
      currentUserName: currentName,
    );
  }

  static int? _userIdForName(List<ManagerEmployeeModel> members, String? name) {
    final needle = (name ?? '').trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final member in members) {
      if (member.name.trim().toLowerCase() == needle) return member.userId;
    }
    return null;
  }

  static bool _isOwnerOrManager(ManagerEmployeeModel member) {
    if (member.badge == ManagerEmployeeBadge.owner ||
        member.badge == ManagerEmployeeBadge.manager) {
      return true;
    }
    final role = member.role.toLowerCase();
    final dept = (member.departmentTitle ?? '').toLowerCase();
    return _isOwnerName(member.name) ||
        role.contains('owner') ||
        role.contains('manager') ||
        dept.contains('owner') ||
        dept.contains('manager');
  }

  static bool _isLeadershipUser(
    List<ManagerEmployeeModel> members,
    int userId,
  ) {
    for (final member in members) {
      if (member.userId == userId) return _isOwnerOrManager(member);
    }
    return false;
  }

  static bool _isLeadershipName(String? name) {
    final value = (name ?? '').trim().toLowerCase();
    return value == 'owner' ||
        value.contains('owner') ||
        value.contains('manager');
  }

  static bool _isOwnerName(String? name) {
    final value = (name ?? '').trim().toLowerCase();
    return value == 'owner' || value.contains('owner');
  }

  static (String?, String?, String?)? _locationFromDay(
    ManagerEmployeeAttendanceDay? day,
  ) {
    if (day == null) return null;
    String? locationId = day.locationId;
    String? locationName = day.locationName;
    String? current = day.currentLocation;
    for (final detail in day.details) {
      current ??= detail.currentLocation;
    }
    if ((locationId == null || locationId.trim().isEmpty) &&
        (locationName == null || locationName.trim().isEmpty) &&
        (current == null || current.trim().isEmpty)) {
      return null;
    }
    return (locationId, locationName ?? current, current);
  }

  static bool _statusLooksLate(String? raw) {
    final value =
        (raw ?? '').toLowerCase().trim().replaceAll(RegExp(r'[\s\-_\/]+'), '');
    if (value.isEmpty) return false;
    if (value.contains('checkout') || value.contains('early')) return false;
    return value == 'late' ||
        value == 'latecheck' ||
        value.contains('latecheckin');
  }
}
