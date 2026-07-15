/// In-memory fast-path over the DB cache. The DB (`AttendanceDao`) is the
/// real source of truth for "is this month cached?" — this tracker just
/// avoids an extra disk hit when the user flips back and forth between
/// months already confirmed loaded earlier in the same app session.
///
/// Keys are "YYYY-MM" strings, matching `AttendanceDao`'s month key format.
class AttendanceCacheTracker {
  AttendanceCacheTracker._();

  static final AttendanceCacheTracker instance = AttendanceCacheTracker._();

  final Set<String> _loadedMonths = <String>{};

  bool isLoaded(String monthKey) => _loadedMonths.contains(monthKey);

  void markLoaded(String monthKey) => _loadedMonths.add(monthKey);

  /// Snapshot for debugging / the spec's `loadedMonths` tracker requirement.
  List<String> get loadedMonths => List.unmodifiable(_loadedMonths);

  void reset() => _loadedMonths.clear();
}
