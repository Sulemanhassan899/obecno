import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_status_filter_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/status_filter_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_status_filters_service.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';

class ManagerStatusFiltersProvider extends BaseProvider {
  ManagerStatusFiltersProvider(this._service);

  final ManagerStatusFiltersService _service;

  List<StatusFilterOption> options = StatusFilterOption.options;

  Future<bool> load() {
    return safeCall<List<ManagerStatusFilter>>(
      operationKey: 'manager_status_filters_load',
      request: (cancelToken) => _service.loadFilters(cancelToken: cancelToken),
      onSuccess: (filters) {
        if (filters.isEmpty) return;
        options = StatusFilterMapper.toOptions(filters);
      },
    );
  }

  Future<void> ensureLoaded() async {
    if (status == ViewStatus.success && options.isNotEmpty) return;
    final ok = await load();
    if (!ok && options.isEmpty) {
      options = StatusFilterOption.options;
      notifyListeners();
    }
  }

  void reset() {
    cancelAll();
    resetViewState();
    options = StatusFilterOption.options;
    notifyListeners();
  }
}
