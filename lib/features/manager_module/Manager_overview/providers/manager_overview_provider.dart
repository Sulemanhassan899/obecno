import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/features/manager_module/Manager_overview/services/manager_overview_service.dart';

class ManagerOverviewProvider extends BaseProvider {
  ManagerOverviewProvider(this._service);

  final ManagerOverviewService _service;

  DateTime selectedDate = _dateOnly(DateTime.now());

  OverviewSummary? summary;
  ManagerDashboardModel? dashboard;
  List<ManagerTeamAttendanceItem> attendance = const [];

  /// [silent] updates counts in place — no loading shimmer / screen refresh.
  Future<bool> load({bool silent = false}) {
    final keepExisting = silent || summary != null;
    return safeCall<OverviewSnapshot>(
      operationKey: 'manager_overview_load',
      silent: keepExisting,
      request: (cancelToken) => _service.loadOverview(
        date: selectedDate,
        cancelToken: cancelToken,
        // Dashboard-only preliminary under-counts (owner punches missing).
        // Skip it once we already painted enriched counts — otherwise the
        // 12s poll flashes Present back to 1 before _withOwner finishes.
        onPreliminary: (result) {
          if (cancelToken.isCancelled) return;
          if (keepExisting) return;
          _apply(result, fromPreliminary: true);
          if (isLoading) setSuccess();
        },
      ),
      onSuccess: (result) => _apply(result),
    );
  }

  void _apply(OverviewSnapshot result, {bool fromPreliminary = false}) {
    selectedDate = result.date;

    // Never let a weaker snapshot wipe a richer Present / Active count.
    // Happens when dashboard.teamAttendanceToday omits the signed-in owner
    // and a later poll re-applies that incomplete list.
    final incoming = result.attendance;
    final mergedAttendance = _preferRicherAttendance(
      current: attendance,
      incoming: incoming,
      allowWeaker: !fromPreliminary && summary == null,
    );
    final teamCount = result.summary.totalTeamMembers;
    final nextSummary = identical(mergedAttendance, incoming)
        ? result.summary
        : OverviewSummary.fromAttendance(
            attendance: mergedAttendance,
            teamMemberCount: teamCount,
          );

    if (fromPreliminary &&
        summary != null &&
        nextSummary.presentToday < summary!.presentToday) {
      return;
    }

    summary = nextSummary;
    dashboard = result.dashboard;
    attendance = mergedAttendance;
    notifyListeners();
  }

  /// Keep punched people from [current] when [incoming] drops them
  /// (incomplete dashboard / cancelled enrichment).
  List<ManagerTeamAttendanceItem> _preferRicherAttendance({
    required List<ManagerTeamAttendanceItem> current,
    required List<ManagerTeamAttendanceItem> incoming,
    required bool allowWeaker,
  }) {
    if (allowWeaker || current.isEmpty) return incoming;

    final incomingPresent = incoming.where((e) => e.hasCheckIn).length;
    final currentPresent = current.where((e) => e.hasCheckIn).length;
    if (incomingPresent >= currentPresent) return incoming;

    final byUser = <int, ManagerTeamAttendanceItem>{};
    final byName = <String, ManagerTeamAttendanceItem>{};

    void remember(ManagerTeamAttendanceItem item) {
      final id = item.userId;
      if (id != null) byUser[id] = item;
      final name = item.employeeName?.trim().toLowerCase();
      if (name != null && name.isNotEmpty) byName[name] = item;
    }

    for (final item in incoming) {
      remember(item);
    }
    for (final item in current) {
      if (!item.hasCheckIn) continue;
      final id = item.userId;
      if (id != null && byUser.containsKey(id)) {
        final existing = byUser[id]!;
        if (!existing.hasCheckIn) byUser[id] = item;
        continue;
      }
      final name = item.employeeName?.trim().toLowerCase() ?? '';
      if (name.isNotEmpty && byName.containsKey(name)) {
        final existing = byName[name]!;
        if (!existing.hasCheckIn) {
          byName[name] = item;
          if (existing.userId != null) byUser[existing.userId!] = item;
        }
        continue;
      }
      remember(item);
    }

    final merged = <ManagerTeamAttendanceItem>[
      ...byUser.values,
      ...byName.values.where(
        (item) => item.userId == null || !byUser.containsKey(item.userId),
      ),
    ];
    return merged;
  }

  /// Pull-to-refresh / tab resume: refresh without blanking the card.
  Future<bool> refresh() => load(silent: summary != null);

  /// Background poll: never flip into a loading state.
  Future<bool> refreshSilent() => load(silent: true);

  void setDate(DateTime date) {
    selectedDate = _dateOnly(date);
    summary = null;
    attendance = const [];
    load();
  }

  void reset() {
    cancelAll();
    resetViewState();
    selectedDate = _dateOnly(DateTime.now());
    summary = null;
    dashboard = null;
    attendance = const [];
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
