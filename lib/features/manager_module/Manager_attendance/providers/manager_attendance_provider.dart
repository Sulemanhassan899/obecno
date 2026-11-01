import 'package:flutter/material.dart';
import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/manager_attendance_filters.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/pending_attendance_overlay.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';

class ManagerAttendanceProvider extends BaseProvider {
  ManagerAttendanceProvider(this._service);

  final ManagerAttendanceService _service;

  DateTime selectedDate = _dateOnly(DateTime.now());
  String statusFilterId = StatusFilterOption.allId;
  String locationId = LocationFilterOption.allId;
  String? locationName;
  List<ManagerTeamAttendanceItem> items = const [];
  List<ManagerEmployeeModel> members = const [];
  List<ManagerLocationModel> offices = const [];
  int total = 0;
  String? holidayName;

  final Map<String, PendingAttendanceSave> _pendingSaves = {};

  /// Leave rows from overview seed / prior stamp. Re-applied after every
  /// reload so On Leave people do not vanish when team-leaves is slow/empty.
  List<ManagerTeamAttendanceItem> _leaveOverlay = const [];

  List<ManagerTeamAttendanceItem>? _tilesItems;
  List<ManagerEmployeeModel>? _tilesMembers;
  List<ManagerLocationModel>? _tilesOffices;
  String? _tilesStatus;
  String? _tilesLocationId;
  String? _tilesLocationName;
  String? _tilesUserId;
  String? _tilesUserName;
  bool? _tilesNonWorkingOnly;
  List<ManagerAttendanceModel>? _tilesCache;

  bool get isAllStatus => ManagerAttendanceFilters.isAllStatus(statusFilterId);

  bool get isHoliday => holidayName != null && holidayName!.trim().isNotEmpty;

  /// Sat / Sun — same empty / punched-in list treatment as holidays.
  bool get isWeekend =>
      selectedDate.weekday == DateTime.saturday ||
      selectedDate.weekday == DateTime.sunday;

  /// Holiday or weekend: calendar-star screen (+ punched-in people if any).
  bool get isNonWorkingDay => isHoliday || isWeekend;

  /// Lines under calendar-star: holiday name, or Sat + Sun dates in a column.
  List<String> get nonWorkingDayLabels {
    if (isHoliday) {
      final name = holidayName?.trim() ?? '';
      return [name.isEmpty ? 'Public Holiday' : name];
    }
    if (isWeekend) return _weekendPairLabels(selectedDate);
    return const [];
  }

  /// Back-compat single line (first label).
  String get nonWorkingDayLabel {
    final labels = nonWorkingDayLabels;
    return labels.isEmpty ? '' : labels.first;
  }

  List<ManagerTeamAttendanceItem> get filteredItems {
    var list = ManagerAttendanceFilters.applyItems(
      source: items,
      selectedStatus: statusFilterId,
      selectedLocation: locationId,
      locationName: locationName,
      members: members,
    );
    // Holiday / weekend: punch activity OR anyone on leave (leave is not
    // weekend-gated — overview On Leave must still list them).
    if (isNonWorkingDay) {
      list = list
          .where(
            (item) =>
                item.isOnLeave ||
                item.hasCheckIn ||
                item.isActive ||
                item.isOpen ||
                item.isCurrentlyOnBreak,
          )
          .toList(growable: false);
    }
    return list;
  }

  List<ManagerAttendanceModel> get tiles {
    final userId = _service.currentUserId;
    final userName = _currentUserName;
    final cached = _tilesCache;
    if (cached != null &&
        identical(items, _tilesItems) &&
        identical(members, _tilesMembers) &&
        identical(offices, _tilesOffices) &&
        statusFilterId == _tilesStatus &&
        locationId == _tilesLocationId &&
        locationName == _tilesLocationName &&
        userId == _tilesUserId &&
        userName == _tilesUserName &&
        isNonWorkingDay == _tilesNonWorkingOnly) {
      return cached;
    }

    final next = TeamAttendanceMapper.toTiles(
      filteredItems,
      currentUserId: userId,
      currentUserName: userName,
      offices: offices,
    );
    _tilesItems = items;
    _tilesMembers = members;
    _tilesOffices = offices;
    _tilesStatus = statusFilterId;
    _tilesLocationId = locationId;
    _tilesLocationName = locationName;
    _tilesUserId = userId;
    _tilesUserName = userName;
    _tilesNonWorkingOnly = isNonWorkingDay;
    _tilesCache = next;
    return next;
  }

  Iterable<PendingAttendanceSave> get pendingSaves => _pendingSaves.values;

  List<ManagerAttendanceModel> searchResults(String query) {
    return TeamAttendanceMapper.toTiles(
      ManagerAttendanceFilters.applyItems(
        source: items,
        selectedStatus: StatusFilterOption.allId,
        selectedLocation: LocationFilterOption.allId,
        searchQuery: query,
        members: members,
      ),
      currentUserId: _service.currentUserId,
      currentUserName: _currentUserName,
      offices: offices,
    );
  }

  void setOffices(List<ManagerLocationModel> next) {
    if (identical(offices, next)) return;
    offices = List<ManagerLocationModel>.from(next);
    _tilesCache = null;
    notifyListeners();
  }

  String? get _currentUserName {
    final id = _service.currentUserId;
    if (id == null || id.isEmpty) return null;
    for (final member in members) {
      if (member.id == id) return member.name;
    }
    return null;
  }

  Future<bool> load() async {
    final holidayFuture = _service.holidayForDate(selectedDate);
    final ok = await safeCall<ManagerTeamAttendanceData>(
      operationKey: 'manager_attendance_load',
      guardAgainstDuplicate: false,
      request: (cancelToken) => _service.loadTeamAttendance(
        date: selectedDate,
        cancelToken: cancelToken,
      ),
      onSuccess: (data) {
        _log(
          'load() API returned ${data.attendance.length} rows: '
          '${data.attendance.map((e) => '${e.employeeName}/${e.userId}=${e.checkin}').join(', ')}',
        );
        final stamped = data.attendance;
        _rememberLeaveOverlay(stamped);
        items = _mergeLeaveOverlay(stamped);
        members = data.members;
        total = items.length;
        _applyPendingToItems();
      },
    );
    try {
      final holiday = await holidayFuture;
      holidayName = holiday?.name.trim().isEmpty == true
          ? 'Public Holiday'
          : holiday?.name;
    } catch (_) {
      holidayName = null;
    }
    notifyListeners();
    return ok;
  }

  Future<ManagerAttendanceDetailsData> loadEmployeeDay({
    required ManagerAttendanceModel employee,
    required DateTime day,
  }) async {
    final fallback = ManagerAttendanceDetailsData.fromEmployee(
      employee: employee,
      day: day,
    );
    final userId = employee.userId;
    if (userId == null) return fallback;
    _log(
      'loadEmployeeDay ${employee.name}/$userId day=$day '
      'listTimes=${employee.checkIn}/${employee.checkOut} '
      'pending=${_pendingSaves[_pendingKey(userId, employee.name)]}',
    );

    try {
      final photoFuture = _service.loadEmployeePhoto(userId: userId);

      final response = await _service.loadEmployeeAttendance(
        userId: userId,
        date: day,
      );
      final fetchedPhoto = await photoFuture;
      final photo = _networkPhoto(employee.photo) ?? fetchedPhoto;

      if (!response.success || response.data == null) {
        _log('loadEmployeeDay GET failed for $userId: ${response.message}');
        return _withPending(
          photo == null || photo.isEmpty
              ? fallback
              : fallback.copyWith(photo: photo),
          userId: userId,
          day: day,
        );
      }

      final details = EmployeeAttendanceMapper.toDetails(
        data: response.data!,
        day: day,
        fallbackName: employee.name,
        fallbackRole: employee.role,
        fallbackPhoto: photo,
        fallbackAttendanceId: employee.attendanceId,
        fallbackUserId: employee.userId,
      );
      // Keep list/fallback punches when the day payload is still empty.
      if (!details.hasAttendance && fallback.hasAttendance) {
        return _withPending(
          fallback.copyWith(
            photo: details.photo ?? photo,
            attendanceId: details.attendanceId,
          ),
          userId: userId,
          day: day,
        );
      }
      return _withPending(details, userId: userId, day: day);
    } catch (_) {
      return _withPending(fallback, userId: userId, day: day);
    }
  }

  ManagerAttendanceDetailsData _withPending(
    ManagerAttendanceDetailsData details, {
    required int? userId,
    required DateTime day,
  }) {
    final pending = _pendingFor(userId: userId, name: details.name, day: day);
    if (pending == null) {
      _log('overlay skip for ${details.name}/$userId (no pending)');
      return details;
    }
    _log(
      'overlay ${details.name}/$userId '
      'api=${details.checkIn}/${details.checkOut} '
      'pending=${pending.checkIn}/${pending.checkOut}',
    );
    return details.withSavedTimes(
      AddAttendanceSaveResult(
        checkIn: _timeOfDay(pending.checkIn),
        checkOut: _timeOfDay(pending.checkOut),
      ),
    );
  }

  static TimeOfDay? _timeOfDay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<bool> refresh() => load();

  void applySavedTimes({
    required int? userId,
    required DateTime day,
    TimeOfDay? checkIn,
    TimeOfDay? checkOut,
    String? employeeName,
  }) {
    if (checkIn == null && checkOut == null) return;
    final key = _pendingKey(userId, employeeName);
    final previous = _pendingSaves[key];
    final next = PendingAttendanceSave(
      userId: userId ?? previous?.userId,
      employeeName: employeeName ?? previous?.employeeName,
      day: _dateOnly(day),
      checkIn: checkIn == null ? previous?.checkIn : _clock(checkIn),
      checkOut: checkOut == null ? previous?.checkOut : _clock(checkOut),
    );
    _pendingSaves[key] = next;
    _log(
      'applySavedTimes key=$key name=${next.employeeName} '
      'in=${next.checkIn} out=${next.checkOut} '
      'pendingKeys=${_pendingSaves.keys.toList()}',
    );
    _applyPendingToItems();
    notifyListeners();
  }

  void _applyPendingToItems() {
    if (_pendingSaves.isEmpty) return;
    _log(
      'applyPending before: '
      '${items.map((e) => '${e.employeeName}=${e.checkin}').join(', ')} '
      'pending=${_pendingSaves.values.toList()}',
    );
    items = PendingAttendanceOverlay.apply(
      items: items,
      pending: _pendingSaves.values,
      selectedDate: selectedDate,
    );
    _log(
      'applyPending after: '
      '${items.map((e) => '${e.employeeName}=${e.checkin}').join(', ')}',
    );
  }

  PendingAttendanceSave? _pendingFor({
    required int? userId,
    required String? name,
    required DateTime day,
  }) {
    final byId = userId == null ? null : _pendingSaves['id:$userId'];
    final byName = _pendingSaves[_pendingKey(null, name)];
    final pending = byId ?? byName;
    if (pending == null ||
        !PendingAttendanceOverlay.sameDay(pending.day, day)) {
      return null;
    }
    return pending;
  }

  static String _pendingKey(int? userId, String? name) {
    if (userId != null) return 'id:$userId';
    return 'name:${(name ?? '').trim().toLowerCase()}';
  }

  static void _log(String message) {}

  static String _clock(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  Future<bool> ensureLoaded() {
    if (isLoading) return Future.value(true);
    if (status == ViewStatus.success) return Future.value(true);
    return load();
  }

  /// Used when jumping from Overview stats: apply that day's date + status.
  /// [seedItems] is the overview list so Active/On Break counts match immediately.
  Future<bool> open({
    DateTime? date,
    String? statusFilter,
    List<ManagerTeamAttendanceItem>? seedItems,
  }) {
    final nextDate = date == null ? selectedDate : _dateOnly(date);
    final nextStatus = StatusFilterOption.idFromLabel(statusFilter);
    final dateChanged = nextDate != selectedDate;

    selectedDate = nextDate;
    statusFilterId = nextStatus;
    locationId = LocationFilterOption.allId;
    locationName = null;

    if (dateChanged) {
      items = const [];
      members = const [];
      total = 0;
      _leaveOverlay = const [];
      _pendingSaves.clear();
    }

    if (seedItems != null && seedItems.isNotEmpty) {
      _rememberLeaveOverlay(seedItems);
      items = _mergeLeaveOverlay(seedItems);
      total = items.length;
      notifyListeners();
    }

    // Always reload so the directory merge includes everyone (including
    // employees with no location), not only the overview live subset.
    return load();
  }

  Future<bool> setDate(DateTime date) {
    selectedDate = _dateOnly(date);
    items = const [];
    members = const [];
    total = 0;
    holidayName = null;
    _leaveOverlay = const [];
    _pendingSaves.clear();
    _log('setDate $selectedDate — cleared pending saves');
    notifyListeners();
    return load();
  }

  void _rememberLeaveOverlay(List<ManagerTeamAttendanceItem> source) {
    final byUser = <int, ManagerTeamAttendanceItem>{
      for (final item in _leaveOverlay)
        if (item.userId != null) item.userId!: item,
    };
    for (final item in source) {
      if (!item.isOnLeave || item.userId == null) continue;
      byUser[item.userId!] = item;
    }
    _leaveOverlay = byUser.values.toList(growable: false);
  }

  List<ManagerTeamAttendanceItem> _mergeLeaveOverlay(
    List<ManagerTeamAttendanceItem> source,
  ) {
    if (_leaveOverlay.isEmpty) return source;

    final leaveByUser = <int, ManagerTeamAttendanceItem>{
      for (final leave in _leaveOverlay)
        if (leave.userId != null) leave.userId!: leave,
    };
    if (leaveByUser.isEmpty) return source;

    final result = <ManagerTeamAttendanceItem>[];
    final seen = <int>{};
    for (final item in source) {
      final userId = item.userId;
      if (userId != null && leaveByUser.containsKey(userId)) {
        seen.add(userId);
        result.add(
          item.isOnLeave
              ? item
              : item.copyWith(status: 'leave', statusLabel: 'On Leave'),
        );
      } else {
        result.add(item);
      }
    }
    for (final entry in leaveByUser.entries) {
      if (seen.contains(entry.key)) continue;
      result.add(entry.value);
    }
    return result;
  }

  void setStatus(String? status) {
    statusFilterId = StatusFilterOption.idFromLabel(status);
    notifyListeners();
  }

  void setLocation({required String id, String? name}) {
    locationId = id.trim().isEmpty ? LocationFilterOption.allId : id;
    locationName = name;
    notifyListeners();
  }

  void reset() {
    cancelAll();
    resetViewState();
    selectedDate = _dateOnly(DateTime.now());
    statusFilterId = StatusFilterOption.allId;
    locationId = LocationFilterOption.allId;
    locationName = null;
    items = const [];
    members = const [];
    offices = const [];
    holidayName = null;
    total = 0;
    _leaveOverlay = const [];
    _pendingSaves.clear();
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static const _weekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const _monthsShort = [
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

  /// e.g. Sat, 10 Oct 2025
  static String _shortDateLabel(DateTime date) {
    final weekday = _weekdaysShort[date.weekday - 1];
    final month = _monthsShort[date.month - 1];
    return '$weekday, ${date.day} $month ${date.year}';
  }

  /// Both days of the weekend, Sat then Sun — shown as a column.
  static List<String> _weekendPairLabels(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final saturday = day.weekday == DateTime.saturday
        ? day
        : day.subtract(const Duration(days: 1));
    final sunday = saturday.add(const Duration(days: 1));
    return [_shortDateLabel(saturday), _shortDateLabel(sunday)];
  }

  static String? _networkPhoto(String? photo) {
    if (photo == null) return null;
    final value = photo.trim();
    if (value.isEmpty || value.startsWith('assets/')) return null;
    return value;
  }
}
