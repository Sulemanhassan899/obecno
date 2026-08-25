import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_status_filter_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/repositories/manager_status_filters_repository.dart';

class ManagerStatusFiltersService {
  ManagerStatusFiltersService(this._repository);

  final ManagerStatusFiltersRepository _repository;

  Future<ApiResponse<List<ManagerStatusFilter>>> loadFilters({
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getFilters(cancelToken: cancelToken);
  }
}
