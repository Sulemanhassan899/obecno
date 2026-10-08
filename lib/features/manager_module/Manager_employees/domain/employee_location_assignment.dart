/// How the employee locations bottom sheet behaves.
enum EmployeeLocationsSheetMode {
  /// Assign/unassign any company locations (multi-select).
  assigned,

  /// Pick exactly one default location (single-select).
  defaultLocation,
}

class EmployeeLocationSavePayload {
  const EmployeeLocationSavePayload({
    required this.defaultLocationId,
    required this.locationIds,
  });

  final String defaultLocationId;
  final List<String> locationIds;

  /// Assigned-locations sheet: keep the current default when it is still
  /// assigned; otherwise fall back to the first remaining selection.
  factory EmployeeLocationSavePayload.fromAssigned({
    required Set<String> selectedIds,
    required String currentDefaultId,
  }) {
    final ids = selectedIds.toList();
    var defaultId = currentDefaultId.trim();
    final stillAssigned = ids.any((id) => id.trim() == defaultId);
    if (defaultId.isEmpty || !stillAssigned) {
      defaultId = ids.isEmpty ? '' : ids.first;
    }
    return EmployeeLocationSavePayload(
      defaultLocationId: defaultId,
      locationIds: ids,
    );
  }

  /// Default-location sheet: one default, and it is always included in
  /// the assigned set.
  factory EmployeeLocationSavePayload.fromDefault({
    required Set<String> assignedIds,
    required String newDefaultId,
  }) {
    final defaultId = newDefaultId.trim();
    final ids = <String>[
      for (final id in assignedIds)
        if (id.trim().isNotEmpty) id,
    ];
    if (defaultId.isNotEmpty && !ids.any((id) => id.trim() == defaultId)) {
      ids.add(defaultId);
    }
    return EmployeeLocationSavePayload(
      defaultLocationId: defaultId,
      locationIds: ids,
    );
  }

  /// After a location is deactivated: drop it from the assigned set and
  /// promote the next remaining location when it was the default.
  factory EmployeeLocationSavePayload.afterRemovingLocation({
    required Iterable<String> assignedIds,
    required String removedLocationId,
    required String currentDefaultId,
  }) {
    final removed = removedLocationId.trim().toLowerCase();
    final remaining = <String>{
      for (final id in assignedIds)
        if (id.trim().isNotEmpty && id.trim().toLowerCase() != removed)
          id.trim(),
    };
    return EmployeeLocationSavePayload.fromAssigned(
      selectedIds: remaining,
      currentDefaultId: currentDefaultId,
    );
  }
}
