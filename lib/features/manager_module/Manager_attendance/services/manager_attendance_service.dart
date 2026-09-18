import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
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

    if (!attendanceResponse.success || attendanceResponse.data == null) {
      return attendanceResponse;
    }

    final merged = TeamAttendanceMapper.mergeWithMembers(
      attendance: attendanceResponse.data!.attendance,
      members: members,
    );
    final withLive = TeamAttendanceMapper.overlayLive(
      items: merged,
      live: live,
    );
    final attendance = await withOwnerAttendance(
      items: withLive,
      members: members,
      date: date,
    );

    return ApiResponse.success(
      ManagerTeamAttendanceData(
        date: attendanceResponse.data!.date,
        departmentId: attendanceResponse.data!.departmentId,
        filter: attendanceResponse.data!.filter,
        search: attendanceResponse.data!.search,
        total: attendance.length,
        attendance: attendance,
        members: members,
      ),
      message: attendanceResponse.message,
      statusCode: attendanceResponse.statusCode,
    );
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
      var response = await repo.getEmployees(cancelToken: cancelToken);
      if (!response.success || response.data == null) {
        response = await repo.getTeamMembers(cancelToken: cancelToken);
      }
      if (!response.success || response.data == null) return const [];
      return response.data!.members;
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
  Future<List<ManagerTeamAttendanceItem>> withOwnerAttendance({
    required List<ManagerTeamAttendanceItem> items,
    required List<ManagerEmployeeModel> members,
    required DateTime date,
  }) async {
    final seeded = _ensureLeadershipRows(items, members);
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
          next[index] = next[index].copyWith(
            userId: userId,
            attendanceId: day?.id ?? next[index].attendanceId,
            employeeName: (next[index].employeeName ?? '').trim().isEmpty
                ? (response.data!.employeeName ?? next[index].employeeName)
                : next[index].employeeName,
            checkin: checkin ?? next[index].checkin,
            checkout: isOpen || onBreak
                ? ''
                : (checkout ?? next[index].checkout),
            isOnBreak: onBreak,
            status: onBreak
                ? 'break'
                : (isOpen
                      ? 'working'
                      : (day?.isLeave == true && !hasCheckin
                            ? 'leave'
                            : next[index].status)),
            isOpen: isOpen || onBreak,
            locationId: next[index].locationId ?? punchLocation?.$1,
            locationName: next[index].locationName ?? punchLocation?.$2,
            currentLocation:
                next[index].currentLocation ??
                punchLocation?.$3 ??
                day?.currentLocation,
            lat: day?.lat ?? next[index].lat,
            lon: day?.lon ?? next[index].lon,
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
}
