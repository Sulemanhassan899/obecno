import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/services/manager_employees_service.dart';

class ManagerEmployeesProvider extends BaseProvider {
  ManagerEmployeesProvider(this._service);

  final ManagerEmployeesService _service;

  List<ManagerEmployeeModel> members = const [];
  int total = 0;

  Future<bool> load({String? search, String? locationId}) {
    return safeCall<ManagerTeamMembersData>(
      operationKey: 'manager_employees_load',
      request: (cancelToken) => _service.loadTeamMembers(
        search: search,
        locationId: locationId,
        cancelToken: cancelToken,
      ),
      onSuccess: (data) {
        members = data.members;
        total = data.total;
      },
    );
  }

  Future<bool> refresh() => load();

  void reset() {
    cancelAll();
    resetViewState();
    members = const [];
    total = 0;
    notifyListeners();
  }
}
