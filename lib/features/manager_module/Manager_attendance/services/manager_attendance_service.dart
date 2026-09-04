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

class ManagerAttendanceService {
  ManagerAttendanceService(
    this._repository, {
    ManagerEmployeesRepository? employeesRepository,
    String? Function()? currentUserIdProvider,
  }) : _employeesRepository = employeesRepository,
       _currentUserIdProvider = currentUserIdProvider;

  final ManagerAttendanceRepository _repository;
  final ManagerEmployeesRepository? _employeesRepository;
  final String? Function()? _currentUserIdProvider;

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

    final attendanceResponse = await attendanceFuture;
    final members = await membersFuture;

    if (!attendanceResponse.success || attendanceResponse.data == null) {
      return attendanceResponse;
    }

    final merged = TeamAttendanceMapper.mergeWithMembers(
      attendance: attendanceResponse.data!.attendance,
      members: members,
    );
    final attendance = await withOwnerAttendance(
      items: merged,
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

  /// Makes sure the signed-in owner is on the list and has today's punches.
  Future<List<ManagerTeamAttendanceItem>> withOwnerAttendance({
    required List<ManagerTeamAttendanceItem> items,
    required List<ManagerEmployeeModel> members,
    required DateTime date,
  }) async {
    final seeded = _ensureOwnerRows(items, members);
    return _hydrateOwnerPunches(items: seeded, members: members, date: date);
  }

  List<ManagerTeamAttendanceItem> _ensureOwnerRows(
    List<ManagerTeamAttendanceItem> items,
    List<ManagerEmployeeModel> members,
  ) {
    final next = [...items];
    final currentId = int.tryParse(_currentUserIdProvider?.call() ?? '');

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
      if (_isOwner(member) ||
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

  Future<List<ManagerTeamAttendanceItem>> _hydrateOwnerPunches({
    required List<ManagerTeamAttendanceItem> items,
    required List<ManagerEmployeeModel> members,
    required DateTime date,
  }) async {
    final currentId = int.tryParse(_currentUserIdProvider?.call() ?? '');
    final ownerIds = <int>{
      if (currentId != null) currentId,
      for (final member in members)
        if (_isOwner(member) && member.userId != null) member.userId!,
    };

    final next = [...items];
    for (var i = 0; i < next.length; i++) {
      final item = next[i];
      final userId = item.userId ?? _userIdForName(members, item.employeeName);
      if (userId == null) continue;
      if (!ownerIds.contains(userId) &&
          !_isOwnerName(item.employeeName) &&
          userId != currentId) {
        continue;
      }

      final needsPunch = !item.hasCheckIn;
      final needsLocation =
          (item.locationId == null || item.locationId!.trim().isEmpty) &&
          (item.locationName == null || item.locationName!.trim().isEmpty) &&
          (item.currentLocation == null ||
              item.currentLocation!.trim().isEmpty);

      try {
        final response = await loadEmployeeAttendance(
          userId: userId,
          date: date,
        );
        if (!response.success || response.data == null) continue;
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
          continue;
        }
        final hasCheckin = (checkin ?? item.checkin)?.trim().isNotEmpty == true;
        next[i] = item.copyWith(
          userId: userId,
          attendanceId: day?.id ?? item.attendanceId,
          employeeName: (item.employeeName ?? '').trim().isEmpty
              ? (response.data!.employeeName ?? item.employeeName)
              : item.employeeName,
          checkin: checkin ?? item.checkin,
          checkout: isOpen || onBreak ? '' : (checkout ?? item.checkout),
          isOnBreak: onBreak,
          status: onBreak
              ? 'break'
              : (isOpen
                    ? 'working'
                    : (day?.isLeave == true && !hasCheckin
                          ? 'leave'
                          : item.status)),
          isOpen: isOpen || onBreak,
          locationId: item.locationId ?? punchLocation?.$1,
          locationName: item.locationName ?? punchLocation?.$2,
          currentLocation:
              item.currentLocation ?? punchLocation?.$3 ?? day?.currentLocation,
          lat: day?.lat ?? item.lat,
          lon: day?.lon ?? item.lon,
        );
      } catch (_) {}
    }
    return TeamAttendanceMapper.statusFirst(next);
  }

  static int? _userIdForName(List<ManagerEmployeeModel> members, String? name) {
    final needle = (name ?? '').trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final member in members) {
      if (member.name.trim().toLowerCase() == needle) return member.userId;
    }
    return null;
  }

  static bool _isOwner(ManagerEmployeeModel member) {
    if (member.badge == ManagerEmployeeBadge.owner) return true;
    return _isOwnerName(member.name) ||
        member.role.toLowerCase().contains('owner') ||
        (member.departmentTitle ?? '').toLowerCase().contains('owner');
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
