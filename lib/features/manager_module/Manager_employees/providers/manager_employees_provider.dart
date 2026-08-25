import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';
import 'package:obecno/features/manager_module/Manager_employees/services/manager_employees_service.dart';

class ManagerEmployeesProvider extends BaseProvider {
  ManagerEmployeesProvider(this._service);

  final ManagerEmployeesService _service;

  List<ManagerEmployeeModel> members = const [];
  int total = 0;
  List<ManagerDepartmentOption> departments = const [];
  List<ManagerDepartmentOption> countries = const [];
  List<ManagerDepartmentOption> cities = const [];
  String? _citiesCountryId;

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

  List<ManagerDepartmentOption> get departmentOptions {
    if (departments.isNotEmpty) return departments;
    final seen = <String>{};
    final items = <ManagerDepartmentOption>[];
    for (final member in members) {
      final id = member.departmentId?.trim() ?? '';
      if (id.isEmpty || id.toLowerCase() == 'all' || !seen.add(id)) continue;
      final name = member.departmentTitle?.trim() ?? '';
      items.add(
        ManagerDepartmentOption(
          id: id,
          name: name.isEmpty ? 'Department $id' : name,
        ),
      );
    }
    return items;
  }

  List<ManagerDepartmentOption> get reportsToOptions {
    final seen = <String>{};
    final items = <ManagerDepartmentOption>[];
    for (final member in members) {
      final id = member.id.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      items.add(ManagerDepartmentOption(id: id, name: member.name));
    }
    return items;
  }

  Future<void> loadDepartments() async {
    final result = await _service.getDepartments();
    if (result.success && result.data != null && result.data!.isNotEmpty) {
      departments = result.data!;
      notifyListeners();
      return;
    }
    if (members.isEmpty) {
      await load();
    }
    notifyListeners();
  }

  Future<void> loadCountries() async {
    final result = await _service.getCountries();
    if (result.success && result.data != null) {
      countries = result.data!;
      notifyListeners();
    }
  }

  Future<void> loadCities(String countryId) async {
    final id = countryId.trim();
    if (id.isEmpty) return;
    _citiesCountryId = id;
    final result = await _service.getCities(countryId: id);
    cities = result.success && result.data != null
        ? result.data!
        : const [];
    notifyListeners();
  }

  void clearCities() {
    _citiesCountryId = null;
    if (cities.isEmpty) return;
    cities = const [];
    notifyListeners();
  }

  Future<void> loadAddEmployeeLookups() async {
    await Future.wait([
      loadDepartments(),
      loadCountries(),
      if (members.isEmpty) load(),
    ]);
  }

  Future<ApiResponse<int>> addEmployees(List<AddEmployeePayload> payloads) {
    return _service.addEmployees(payloads);
  }

  void reset() {
    cancelAll();
    resetViewState();
    members = const [];
    total = 0;
    departments = const [];
    countries = const [];
    cities = const [];
    _citiesCountryId = null;
    notifyListeners();
  }
}
