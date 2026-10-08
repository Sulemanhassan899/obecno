import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';

class LocationFilterMapper {
  LocationFilterMapper._();

  static List<LocationFilterOption> toFilterOptions(
    List<ManagerLocationModel> locations, {
    String? nearestId,
    bool activeOnly = false,
  }) {
    final source = activeOnly
        ? locations.where((location) => location.isActive)
        : locations;
    return source
        .map(
          (location) => LocationFilterOption(
            id: location.id,
            name: location.name,
            address: location.address.trim().isEmpty ? null : location.address,
            isNear: nearestId != null && nearestId == location.id,
          ),
        )
        .toList(growable: false);
  }
}
