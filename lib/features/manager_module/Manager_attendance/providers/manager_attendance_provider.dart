import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/manager_attendance_filters.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/pending_attendance_overlay.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
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
  int total = 0;

  final Map<String, PendingAttendanceSave> _pendingSaves = {};

  bool get isAllStatus => ManagerAttendanceFilters.isAllStatus(statusFilterId);

  List<ManagerTeamAttendanceItem> get filteredItems {
    return ManagerAttendanceFilters.applyItems(
      source: items,
      selectedStatus: statusFilterId,
      selectedLocation: locationId,
      locationName: locationName,
      members: members,
    );
  }

  List<ManagerAttendanceModel> get tiles =>
      TeamAttendanceMapper.toTiles(filteredItems);

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
    );
  }

  Future<bool> load() {
    return safeCall<ManagerTeamAttendanceData>(
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
        items = data.attendance;
        members = data.members;
        total = data.total;
        _applyPendingToItems();
      },
    );
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

  static void _log(String message) {
    debugPrint('[ManagerAttendance] $message');
  }

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
  Future<bool> open({DateTime? date, String? statusFilter}) {
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
      _pendingSaves.clear();
    }

    if (dateChanged || items.isEmpty || status != ViewStatus.success) {
      return load();
    }
    notifyListeners();
    return Future.value(true);
  }

  Future<bool> setDate(DateTime date) {
    selectedDate = _dateOnly(date);
    items = const [];
    members = const [];
    total = 0;
    _pendingSaves.clear();
    _log('setDate $selectedDate — cleared pending saves');
    notifyListeners();
    return load();
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
    total = 0;
    _pendingSaves.clear();
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String? _networkPhoto(String? photo) {
    if (photo == null) return null;
    final value = photo.trim();
    if (value.isEmpty || value.startsWith('assets/')) return null;
    return value;
  }
}
