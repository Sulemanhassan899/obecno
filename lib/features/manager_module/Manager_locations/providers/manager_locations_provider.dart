import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_filter_mapper.dart';
import 'package:obecno/features/manager_module/Manager_locations/services/manager_locations_service.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';

class ManagerLocationsProvider extends BaseProvider {
  ManagerLocationsProvider(this._service);

  final ManagerLocationsService _service;

  List<ManagerLocationModel> locations = const [];

  List<LocationFilterOption> get filterOptions =>
      LocationFilterMapper.toFilterOptions(locations);

  ManagerLocationModel? byId(String id) {
    final selected = id.trim().toLowerCase();
    if (selected.isEmpty) return null;
    for (final location in locations) {
      if (location.id.trim().toLowerCase() == selected) return location;
    }
    return null;
  }

  Future<bool> load() {
    return safeCall<List<ManagerLocationModel>>(
      operationKey: 'manager_locations_load',
      request: (cancelToken) => _service.loadLocations(
        date: DateTime.now(),
        cancelToken: cancelToken,
      ),
      onSuccess: (data) => locations = data,
    );
  }

  Future<bool> refresh() => load();

  void reset() {
    cancelAll();
    resetViewState();
    locations = const [];
    notifyListeners();
  }
}
