import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/manager_attendance_filters.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
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
  int total = 0;

  bool get isAllStatus => ManagerAttendanceFilters.isAllStatus(statusFilterId);

  List<ManagerTeamAttendanceItem> get filteredItems {
    return ManagerAttendanceFilters.applyItems(
      source: items,
      selectedStatus: statusFilterId,
      selectedLocation: locationId,
      locationName: locationName,
    );
  }

  List<ManagerAttendanceModel> get tiles =>
      TeamAttendanceMapper.toTiles(filteredItems);

  List<ManagerAttendanceModel> searchResults(String query) {
    return TeamAttendanceMapper.toTiles(
      ManagerAttendanceFilters.applyItems(
        source: items,
        selectedStatus: StatusFilterOption.allId,
        selectedLocation: LocationFilterOption.allId,
        searchQuery: query,
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
        items = data.attendance;
        total = data.total;
        if (data.date != null) {
          selectedDate = _dateOnly(data.date!);
        }
      },
    );
  }

  Future<bool> refresh() => load();

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
      total = 0;
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
    total = 0;
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
    total = 0;
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
