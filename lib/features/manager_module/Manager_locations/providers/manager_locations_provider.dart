import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_filter_mapper.dart';
import 'package:obecno/features/manager_module/Manager_locations/services/manager_locations_service.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';

class ManagerLocationsProvider extends BaseProvider {
  ManagerLocationsProvider(this._service);

  final ManagerLocationsService _service;

  List<ManagerLocationModel> locations = const [];

  /// Survives API reloads when the list payload omits `is_active`.
  final Set<String> _inactiveOverrideIds = {};

  int _statsGeneration = 0;

  List<LocationFilterOption> get filterOptions =>
      LocationFilterMapper.toFilterOptions(locations);

  /// Active offices only — used for employee assignment / default pickers.
  List<LocationFilterOption> get activeFilterOptions =>
      LocationFilterMapper.toFilterOptions(locations, activeOnly: true);

  ManagerLocationModel? byId(String id) {
    final selected = id.trim().toLowerCase();
    if (selected.isEmpty) return null;
    for (final location in locations) {
      if (location.id.trim().toLowerCase() == selected) return location;
    }
    return null;
  }

  /// Persist activate/deactivate locally so overview + settings stay in sync
  /// even if the next GET list does not include `is_active`.
  void setLocationActive({
    required String locationId,
    required bool isActive,
  }) {
    final key = locationId.trim().toLowerCase();
    if (key.isEmpty) return;

    if (isActive) {
      _inactiveOverrideIds.remove(key);
    } else {
      _inactiveOverrideIds.add(key);
    }

    debugPrint(
      '[LocationStatus] provider.setLocationActive '
      'id=$locationId isActive=$isActive '
      'overrides=${_inactiveOverrideIds.join(",")}',
    );

    locations = [
      for (final location in locations)
        location.id.trim().toLowerCase() == key
            ? location.copyWith(isActive: isActive)
            : location,
    ];
    notifyListeners();
  }

  Future<bool> load() async {
    final ok = await safeCall<List<ManagerLocationModel>>(
      operationKey: 'manager_locations_load',
      request: (cancelToken) => _service.loadLocations(
        date: DateTime.now(),
        cancelToken: cancelToken,
      ),
      onSuccess: (data) {
        locations = _applyActiveOverrides(data);
        debugPrint(
          '[LocationStatus] provider.load '
          'count=${locations.length} '
          'inactive=${locations.where((l) => !l.isActive).map((l) => l.id).join(",")}',
        );
      },
    );
    if (ok) {
      unawaited(_enrichAttendanceStats());
    }
    return ok;
  }

  /// Background pass so Overview count is not blocked on team attendance.
  Future<void> _enrichAttendanceStats() async {
    final generation = ++_statsGeneration;
    final snapshot = List<ManagerLocationModel>.from(locations);
    if (snapshot.isEmpty) return;

    final stamped = await _service.enrichWithAttendanceStats(
      locations: snapshot,
      date: DateTime.now(),
    );
    if (generation != _statsGeneration) return;
    if (stamped.isEmpty) return;

    // Keep any activate/deactivate overrides applied while stats were loading.
    locations = _applyActiveOverrides(stamped);
    notifyListeners();
  }

  List<ManagerLocationModel> _applyActiveOverrides(
    List<ManagerLocationModel> incoming,
  ) {
    // Trust explicit API false; keep overrides when API defaults to true.
    for (final location in incoming) {
      final key = location.id.trim().toLowerCase();
      if (!location.isActive) {
        _inactiveOverrideIds.add(key);
      } else if (_inactiveOverrideIds.contains(key)) {
        // Keep override until activate clears it.
      }
    }

    return [
      for (final location in incoming)
        _inactiveOverrideIds.contains(location.id.trim().toLowerCase())
            ? location.copyWith(isActive: false)
            : location,
    ];
  }

  Future<bool> refresh() => load();

  void reset() {
    _statsGeneration++;
    cancelAll();
    resetViewState();
    locations = const [];
    _inactiveOverrideIds.clear();
    notifyListeners();
  }
}
