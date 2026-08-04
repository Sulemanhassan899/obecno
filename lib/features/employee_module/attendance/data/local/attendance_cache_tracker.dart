class AttendanceCacheTracker {
  AttendanceCacheTracker._();

  static final AttendanceCacheTracker instance = AttendanceCacheTracker._();

  final Map<String, Set<String>> _loadedMonthsByUser = <String, Set<String>>{};

  bool isLoaded(String userId, String monthKey) =>
      _loadedMonthsByUser[userId]?.contains(monthKey) ?? false;

  void markLoaded(String userId, String monthKey) {
    _loadedMonthsByUser.putIfAbsent(userId, () => <String>{}).add(monthKey);
  }

  /// Snapshot for debugging / the spec's `loadedMonths` tracker requirement.
  List<String> loadedMonths(String userId) =>
      List.unmodifiable(_loadedMonthsByUser[userId] ?? const <String>{});

  /// Clears every user's cache-loaded state. Safe to call broadly (e.g. on
  /// logout) since only one user is ever active on the device at a time.
  void reset() => _loadedMonthsByUser.clear();

  /// Clears cache-loaded state for a single user only, leaving any other
  /// user's tracked state untouched.
  void resetForUser(String userId) => _loadedMonthsByUser.remove(userId);
}
