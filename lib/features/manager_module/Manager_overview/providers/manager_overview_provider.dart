import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/features/manager_module/Manager_overview/services/manager_overview_service.dart';

class ManagerOverviewProvider extends BaseProvider {
  ManagerOverviewProvider(this._service);

  final ManagerOverviewService _service;

  DateTime selectedDate = _dateOnly(DateTime.now());

  OverviewSummary? summary;
  ManagerDashboardModel? dashboard;
  List<ManagerTeamAttendanceItem> attendance = const [];

  Future<bool> load() {
    return safeCall<OverviewSnapshot>(
      operationKey: 'manager_overview_load',
      request: (cancelToken) =>
          _service.loadOverview(date: selectedDate, cancelToken: cancelToken),
      onSuccess: (result) {
        selectedDate = result.date;
        summary = result.summary;
        dashboard = result.dashboard;
        attendance = result.attendance;
      },
    );
  }

  Future<bool> refresh() => load();

  void setDate(DateTime date) {
    selectedDate = _dateOnly(date);
    load();
  }

  void reset() {
    cancelAll();
    resetViewState();
    selectedDate = _dateOnly(DateTime.now());
    summary = null;
    dashboard = null;
    attendance = const [];
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
