import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/repositories/manager_employees_repository.dart';

class ManagerEmployeesService {
  ManagerEmployeesService(
    this._repository, {
    String? Function()? currentUserIdProvider,
  }) : _currentUserIdProvider = currentUserIdProvider;

  final ManagerEmployeesRepository _repository;
  final String? Function()? _currentUserIdProvider;

  Future<ApiResponse<ManagerTeamMembersData>> loadTeamMembers({
    String? search,
    String? locationId,
    ApiCancelToken? cancelToken,
  }) async {
    final response = await _repository.getTeamMembers(
      search: search,
      locationId: locationId,
      cancelToken: cancelToken,
    );

    if (!response.success || response.data == null) return response;

    final currentUserId = _currentUserIdProvider?.call();
    if (currentUserId == null || currentUserId.isEmpty) return response;

    final marked = response.data!.members
        .map(
          (member) => member.id == currentUserId
              ? member.copyWith(badge: ManagerEmployeeBadge.you)
              : member,
        )
        .toList(growable: false);

    return ApiResponse.success(
      ManagerTeamMembersData(total: response.data!.total, members: marked),
      message: response.message,
      statusCode: response.statusCode,
    );
  }
}
