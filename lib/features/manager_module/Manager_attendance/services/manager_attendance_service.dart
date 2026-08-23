import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/manager_module/Manager_attendance/repositories/manager_attendance_repository.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class ManagerAttendanceService {
  ManagerAttendanceService(this._repository);

  final ManagerAttendanceRepository _repository;

  Future<ApiResponse<ManagerTeamAttendanceData>> loadTeamAttendance({
    required DateTime date,
    String? search,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getTeamAttendance(
      date: _yyyyMMdd(date),
      search: search,
      cancelToken: cancelToken,
    );
  }

  static String yyyyMMdd(DateTime date) => _yyyyMMdd(date);

  static String _yyyyMMdd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
