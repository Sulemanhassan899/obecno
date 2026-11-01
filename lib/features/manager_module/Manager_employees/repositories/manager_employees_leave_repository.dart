import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_resources.dart';
import 'package:obecno/features/manager_module/Manager_employees/repositories/manager_employees_repository.dart';

/// Thin façade over leave-related methods on [ManagerEmployeesRepository].
///
/// Keeps the god-repository intact for now while giving leave sheets a smaller
/// import surface. Prefer this for new leave call sites.
class ManagerEmployeesLeaveRepository {
  ManagerEmployeesLeaveRepository(this._employees);

  final ManagerEmployeesRepository _employees;

  Future<ApiResponse<List<ManagerEmployeeLeaveRequest>>> getEmployeeLeaves({
    required int userId,
    String? status,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    return _employees.getEmployeeLeaves(
      userId: userId,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerEmployeeLeaveRequest>> createEmployeeLeave({
    required int userId,
    required int leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
    String? typeName,
    ApiCancelToken? cancelToken,
  }) {
    return _employees.createEmployeeLeave(
      userId: userId,
      leaveTypeId: leaveTypeId,
      startDate: startDate,
      endDate: endDate,
      note: note,
      typeName: typeName,
      cancelToken: cancelToken,
    );
  }
}
