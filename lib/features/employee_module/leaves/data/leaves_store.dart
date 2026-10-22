import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/services/connectivity_service.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/employee_module/leaves/data/local/leave_cache_service.dart';
import 'package:obecno/features/employee_module/leaves/data/local/leave_queue_service.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/data/services/leaves_service.dart';
import 'package:obecno/main.dart';

/// Live employee leaves data backed by `/employee/leaves*` APIs.
///
/// Offline-first: lists / sheet details hydrate from [LeaveCacheService], and
/// apply/update while offline is queued via [LeaveQueueService] then flushed
/// automatically when connectivity returns (same idea as clock check-in).
class LeavesStore extends ChangeNotifier {
  LeavesStore._() {
    _connectivitySub = ConnectivityService.stream.listen((online) {
      if (online) unawaited(syncPendingApplies());
    });
  }

  static final LeavesStore instance = LeavesStore._();

  LeavesService? _serviceOverride;
  LeavesService get _service =>
      _serviceOverride ?? LeavesService(bindings.apiClient);

  final LeaveCacheService _cache = LeaveCacheService();
  final LeaveQueueService _queue = LeaveQueueService();

  final List<LeaveTypeInfo> _types = [];
  final List<LeaveRequest> _requests = [];
  final List<LeaveHoliday> _holidays = [];

  String quotaResetLabel = 'Leaves quota will be reset after the leave year';
  String? lastError;
  String? lastSuccessMessage;
  bool isLoading = false;
  bool isSubmitting = false;
  bool _loadedOnce = false;
  bool _holidaysLoaded = false;
  bool _hydratedFromCache = false;
  Future<void>? _loadInFlight;
  Future<void>? _holidaysInFlight;
  Future<void>? _syncInFlight;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _statusPoll;
  int _statusWatchers = 0;

  String get _userId => bindings.authProvider.user?.id ?? '';

  List<LeaveTypeInfo> get types => List.unmodifiable(_types);

  List<LeaveRequest> get requests {
    final sorted = List<LeaveRequest>.from(_requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  List<LeaveHoliday> get holidays => List.unmodifiable(_holidays);

  /// True after the first holidays fetch finishes (success or failure).
  bool get holidaysLoaded => _holidaysLoaded;

  bool get isHolidaysLoading => _holidaysInFlight != null;

  int get totalAvailable =>
      _types.fold<int>(0, (sum, type) => sum + type.available);

  LeaveBalancesSummary get balances => LeaveBalancesSummary.fromTypes(_types);

  LeaveTypeInfo? typeById(String id) {
    for (final type in _types) {
      if (type.id == id) return type;
    }
    return null;
  }

  LeaveTypeInfo? typeByNameHint(String needle) {
    final lower = needle.toLowerCase();
    for (final type in _types) {
      if (type.id.toLowerCase().contains(lower) ||
          type.name.toLowerCase().contains(lower)) {
        return type;
      }
    }
    return null;
  }

  LeaveRequest? requestById(String id) {
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  /// Leave types for the overview cards (prefers casual/sick/emergency/marriage).
  List<LeaveTypeInfo> get overviewTypes {
    const preferred = ['casual', 'sick', 'emergency', 'marriage'];
    final matched = <LeaveTypeInfo>[];
    for (final needle in preferred) {
      final type = typeByNameHint(needle);
      if (type != null && !matched.any((t) => t.id == type.id)) {
        matched.add(type);
      }
    }
    if (matched.isNotEmpty) return matched;
    return types;
  }

  /// Leave types for the apply picker.
  List<LeaveTypeInfo> get pickerTypes {
    if (_types.isEmpty) return const [];
    const preferred = [
      'casual',
      'sick',
      'misc',
      'miscellaneous',
      'paternity',
      'bereavement',
    ];
    final matched = <LeaveTypeInfo>[];
    for (final needle in preferred) {
      final type = typeByNameHint(needle);
      if (type != null && !matched.any((t) => t.id == type.id)) {
        matched.add(type);
      }
    }
    return matched.isNotEmpty ? matched : types;
  }

  List<LeaveTimelineEvent> timelineEventsForDay(DateTime day) {
    final events = <LeaveTimelineEvent>[];
    for (final request in requests) {
      if (!request.coversDate(day)) continue;
      events.addAll(request.timeline);
    }
    events.sort((a, b) => b.at.compareTo(a.at));
    return events;
  }

  List<LeaveRequest> requestsForDay(DateTime day) {
    return [
      for (final request in requests)
        if (request.coversDate(day)) request,
    ];
  }

  /// True when an approved leave covers [day] (calendar day).
  bool isOnApprovedLeave(DateTime day) {
    for (final request in _requests) {
      if (request.status != LeaveRequestStatus.approved) continue;
      if (request.coversDate(day)) return true;
    }
    return false;
  }

  LeaveRequest? requestForTimelineEvent(String eventId) {
    for (final request in _requests) {
      for (final event in request.timeline) {
        if (event.id == eventId) return request;
      }
    }
    return null;
  }

  Future<void> ensureLoaded({bool force = false}) async {
    await _hydrateFromCacheIfNeeded();
    if (!force && _loadedOnce && _loadInFlight == null) {
      // Screenshot / widget tests inject a service override — skip sync so
      // ConnectivityService / platform channels cannot hang the harness.
      if (_serviceOverride == null) {
        unawaited(syncPendingApplies());
      }
      return;
    }
    if (force) _loadedOnce = false;
    await refresh();
    if (_serviceOverride == null) {
      unawaited(syncPendingApplies());
    }
  }

  Future<void> ensureHolidaysLoaded({bool force = false}) async {
    await _hydrateFromCacheIfNeeded();
    if (!force && _holidaysLoaded && _holidaysInFlight == null) {
      return;
    }
    if (force) _holidaysLoaded = false;
    await _loadHolidays();
  }

  Future<void> refreshHolidays() => ensureHolidaysLoaded(force: true);

  Future<void> _hydrateFromCacheIfNeeded({bool force = false}) async {
    if (_hydratedFromCache && !force) return;
    final userId = _userId;
    if (userId.isEmpty) return;
    final snapshot = await _cache.load(userId);
    _hydratedFromCache = true;
    if (snapshot == null) return;
    if (_types.isEmpty && snapshot.types.isNotEmpty) {
      _types.addAll(snapshot.types);
    }
    if (_requests.isEmpty && snapshot.requests.isNotEmpty) {
      _requests.addAll(snapshot.requests);
    }
    if (_holidays.isEmpty && snapshot.holidays.isNotEmpty) {
      _holidays.addAll(snapshot.holidays);
      _holidaysLoaded = true;
    }
    if (snapshot.quotaResetLabel.trim().isNotEmpty) {
      quotaResetLabel = snapshot.quotaResetLabel;
    }
    if (_types.isNotEmpty || _requests.isNotEmpty) {
      _loadedOnce = true;
    }
    notifyListeners();
  }

  Future<void> _persistCache() async {
    final userId = _userId;
    if (userId.isEmpty) return;
    await _cache.save(
      userId: userId,
      types: _types,
      requests: _requests,
      holidays: _holidays,
      quotaResetLabel: quotaResetLabel,
    );
  }

  /// Clears in-memory + persisted leave data (logout).
  Future<void> clearLocal({String? userId}) async {
    final id = (userId != null && userId.isNotEmpty) ? userId : _userId;
    _types.clear();
    _requests.clear();
    _holidays.clear();
    _loadedOnce = false;
    _holidaysLoaded = false;
    _hydratedFromCache = false;
    lastError = null;
    lastSuccessMessage = null;
    notifyListeners();
    if (id.isNotEmpty) {
      await Future.wait([_cache.clear(id), _queue.clear(id)]);
    }
  }

  /// Keep pending leave statuses fresh while Leaves screens are open.
  void watchPendingStatuses() {
    if (_serviceOverride != null) return;
    _statusWatchers++;
    _statusPoll ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (_requests.any((r) => r.isPending)) {
        refresh();
      }
    });
  }

  void unwatchPendingStatuses() {
    if (_statusWatchers > 0) _statusWatchers--;
    if (_statusWatchers == 0) {
      _statusPoll?.cancel();
      _statusPoll = null;
    }
  }

  Future<void> refresh() {
    final existing = _loadInFlight;
    if (existing != null) return existing;
    final future = _doRefresh();
    _loadInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadInFlight, future)) _loadInFlight = null;
    });
  }

  Future<void> _doRefresh() async {
    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      final online = await ConnectivityService.isConnected();
      if (!online) {
        // Keep showing cached lists/sheet details; do not wipe memory.
        if (_types.isEmpty && _requests.isEmpty) {
          await _hydrateFromCacheIfNeeded();
        }
        _loadedOnce = _types.isNotEmpty || _requests.isNotEmpty || _loadedOnce;
        return;
      }

      final service = _service;
      final typesFuture = service.getTypes();
      final balancesFuture = service.getBalances();
      final leavesFuture = service.getLeaves();

      final typesRes = await typesFuture;
      final balancesRes = await balancesFuture;
      final leavesRes = await leavesFuture;

      final errors = <String>[];
      if (!typesRes.success) {
        errors.add(typesRes.message ?? 'Failed to load leave types');
      }
      if (!balancesRes.success) {
        errors.add(balancesRes.message ?? 'Failed to load leave balances');
      }
      if (!leavesRes.success) {
        errors.add(leavesRes.message ?? 'Failed to load leaves');
      }

      final typeList = <LeaveTypeInfo>[];
      if (typesRes.success && typesRes.data != null) {
        typeList.addAll(typesRes.data!);
      }

      final balancesPayload = balancesRes.data;
      if (balancesRes.success && balancesPayload != null) {
        if (balancesPayload.resetLabel != null &&
            balancesPayload.resetLabel!.trim().isNotEmpty) {
          quotaResetLabel = balancesPayload.resetLabel!.trim();
        }
        _mergeTypes(typeList, balancesPayload.types);
      }

      // Prefer server payload; if empty + we already have cache, keep cache.
      if (typeList.isNotEmpty || _types.isEmpty) {
        _types
          ..clear()
          ..addAll(typeList);
      }

      if (leavesRes.success && leavesRes.data != null) {
        _replaceRequestsPreservingLocals(leavesRes.data!);
      }

      if (errors.isNotEmpty && _types.isEmpty && _requests.isEmpty) {
        lastError = errors.first;
      }

      _loadedOnce = true;
      await _persistCache();
    } catch (e) {
      // Network/parse failures: keep prior / cached data for offline viewing.
      if (_types.isEmpty && _requests.isEmpty) {
        await _hydrateFromCacheIfNeeded();
        lastError = _types.isEmpty && _requests.isEmpty ? e.toString() : null;
      } else {
        lastError = null;
      }
      _loadedOnce = _types.isNotEmpty || _requests.isNotEmpty || _loadedOnce;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _replaceRequestsPreservingLocals(List<LeaveRequest> incoming) {
    final previousStatus = <String, LeaveRequestStatus>{
      for (final request in _requests) request.id: request.status,
    };
    final previousById = <String, LeaveRequest>{
      for (final request in _requests) request.id: request,
    };
    final locals = _requests
        .where((r) => r.id.startsWith('local_'))
        .toList(growable: false);

    LeaveRequest mergeNoteAndActors(LeaveRequest next) {
      final prev = previousById[next.id];
      if (prev == null) return next;
      var merged = next;
      // List payloads often omit the employee note — keep the last known one.
      if (merged.note.trim().isEmpty && prev.note.trim().isNotEmpty) {
        merged = merged.copyWith(note: prev.note);
      }
      if (prev.timeline.isEmpty) return merged;
      final enriched = <LeaveTimelineEvent>[
        for (final event in merged.timeline)
          _enrichTimelineActor(event, prev.timeline),
      ];
      return enriched == merged.timeline
          ? merged
          : merged.copyWith(timeline: enriched);
    }

    _requests
      ..clear()
      ..addAll(incoming.map(mergeNoteAndActors));

    for (final local in locals) {
      final mirrored = _requests.any(
        (r) =>
            r.startDate.year == local.startDate.year &&
            r.startDate.month == local.startDate.month &&
            r.startDate.day == local.startDate.day &&
            r.endDate.year == local.endDate.year &&
            r.endDate.month == local.endDate.month &&
            r.endDate.day == local.endDate.day &&
            (r.typeId == local.typeId ||
                r.typeName.toLowerCase() == local.typeName.toLowerCase()),
      );
      if (!mirrored) _requests.insert(0, local);
    }

    for (final request in _requests) {
      final prev = previousStatus[request.id];
      if (prev == LeaveRequestStatus.pending && request.status != prev) {
        debugPrint(
          'ℹ️ [Leaves] status ${request.id}: pending → ${request.status.name}',
        );
        AppLogger.info(
          '[LeavesStore] status ${request.id}: pending → ${request.status.name}',
        );
      }
    }
  }

  LeaveTimelineEvent _enrichTimelineActor(
    LeaveTimelineEvent event,
    List<LeaveTimelineEvent> previous,
  ) {
    if (event.kind != LeaveTimelineKind.approved &&
        event.kind != LeaveTimelineKind.rejected) {
      return event;
    }
    final current = (event.actorName ?? '').trim();
    if (current.isNotEmpty && current.toLowerCase() != 'manager') {
      return event;
    }
    for (final prev in previous) {
      if (prev.kind != event.kind) continue;
      final name = (prev.actorName ?? '').trim();
      if (name.isNotEmpty && name.toLowerCase() != 'manager') {
        return event.copyWith(actorName: name);
      }
    }
    return event;
  }

  void _mergeTypes(List<LeaveTypeInfo> into, List<LeaveTypeInfo> fromBalances) {
    if (into.isEmpty) {
      into.addAll(fromBalances);
      return;
    }
    for (final balance in fromBalances) {
      final index = into.indexWhere(
        (t) =>
            t.id == balance.id ||
            t.name.toLowerCase() == balance.name.toLowerCase(),
      );
      if (index < 0) {
        into.add(balance);
        continue;
      }
      final existing = into[index];
      into[index] = existing.copyWith(
        available: balance.available,
        total: balance.total > 0 ? balance.total : existing.total,
        resetLabel: balance.resetLabel,
        requiresDocument:
            existing.requiresDocument || balance.requiresDocument,
      );
    }
  }

  Future<void> _loadHolidays() {
    final existing = _holidaysInFlight;
    if (existing != null) return existing;
    final future = _doLoadHolidays();
    _holidaysInFlight = future;
    return future.whenComplete(() {
      if (identical(_holidaysInFlight, future)) _holidaysInFlight = null;
    });
  }

  Future<void> _doLoadHolidays() async {
    try {
      final now = DateTime.now();
      // Current + next year only (no previous-year holidays).
      final months = <String>[
        for (var year = now.year; year <= now.year + 1; year++)
          for (var month = 1; month <= 12; month++)
            '$year-${month.toString().padLeft(2, '0')}',
      ];

      final byKey = <String, LeaveHoliday>{};
      // Fetch in chunks to avoid overwhelming the API.
      const chunkSize = 6;
      for (var i = 0; i < months.length; i += chunkSize) {
        final chunk = months.sublist(
          i,
          i + chunkSize > months.length ? months.length : i + chunkSize,
        );
        final responses = await Future.wait(
          chunk.map(
            (month) =>
                bindings.attendanceService.getCompanyHolidays(month: month),
          ),
        );
        for (final response in responses) {
          if (!response.success || response.data == null) continue;
          for (final HolidayInfo holiday in response.data!) {
            final key =
                '${holiday.date.year}-${holiday.date.month}-${holiday.date.day}';
            byKey.putIfAbsent(
              key,
              () => LeaveHoliday(date: holiday.date, name: holiday.name),
            );
          }
        }
      }

      // Also pull the dedicated company-calendar year payloads when available.
      final yearResponses = await Future.wait([
        for (final year in [now.year, now.year + 1])
          _service.getCompanyHolidaysForYear(year),
      ]);
      for (final response in yearResponses) {
        if (!response.success || response.data == null) continue;
        for (final holiday in response.data!) {
          final key =
              '${holiday.date.year}-${holiday.date.month}-${holiday.date.day}';
          byKey.putIfAbsent(key, () => holiday);
        }
      }

      final sorted = byKey.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final collapsed = _collapseMultiDayHolidays(sorted);
      if (collapsed.isNotEmpty || _holidays.isEmpty) {
        _holidays
          ..clear()
          ..addAll(collapsed);
      }
      _holidaysLoaded = true;
      await _persistCache();
      notifyListeners();
    } catch (_) {
      // Keep previous / cached holidays; holidays are optional for leave flows.
      if (_holidays.isEmpty) {
        await _hydrateFromCacheIfNeeded();
      }
      _holidaysLoaded = true;
      notifyListeners();
    }
  }

  /// Merge consecutive same-named holiday days into one card with day count.
  List<LeaveHoliday> _collapseMultiDayHolidays(List<LeaveHoliday> input) {
    if (input.isEmpty) return input;
    final out = <LeaveHoliday>[];
    var current = input.first;
    var days = current.days;
    for (var i = 1; i < input.length; i++) {
      final next = input[i];
      final expected = current.date.add(Duration(days: days));
      final sameName =
          current.name.trim().toLowerCase() == next.name.trim().toLowerCase();
      final consecutive = next.date.year == expected.year &&
          next.date.month == expected.month &&
          next.date.day == expected.day;
      if (sameName && consecutive) {
        days += next.days;
        continue;
      }
      out.add(LeaveHoliday(date: current.date, name: current.name, days: days));
      current = next;
      days = next.days;
    }
    out.add(LeaveHoliday(date: current.date, name: current.name, days: days));
    return out;
  }

  Future<LeaveRequest?> applyLeave({
    required String typeId,
    required DateTime startDate,
    required DateTime endDate,
    required String note,
    String? documentName,
  }) async {
    isSubmitting = true;
    lastError = null;
    lastSuccessMessage = null;
    notifyListeners();
    try {
      final type = typeById(typeId);
      final beforeIds = _requests.map((r) => r.id).toSet();
      final trimmedNote = note.trim().isEmpty
          ? "I've been feeling unwell due to frequent business trips."
          : note.trim();

      AppLogger.info(
        '[LeavesStore] applyLeave start typeId=$typeId '
        'typeName=${type?.name} '
        '${startDate.toIso8601String()} → ${endDate.toIso8601String()}',
      );

      final online = await ConnectivityService.isConnected();
      if (!online) {
        return _enqueueApply(
          typeId: typeId,
          typeName: type?.name ?? typeId,
          startDate: startDate,
          endDate: endDate,
          note: trimmedNote,
          documentName: documentName,
        );
      }

      try {
        final response = await _service.applyLeave(
          typeId: typeId,
          typeName: type?.name,
          startDate: startDate,
          endDate: endDate,
          note: trimmedNote,
          documentName: documentName,
        );
        final code = response.statusCode;
        if (!response.success || (code != null && code >= 400)) {
          lastError = response.message ??
              response.firstFieldMessage ??
              'Failed to apply leave';
          AppLogger.info('[LeavesStore] applyLeave FAILED: $lastError');
          return null;
        }

        lastSuccessMessage = response.message;
        await refresh();

        final created = response.data;
        if (created != null) {
          final existing = requestById(created.id);
          if (existing != null) {
            AppLogger.info(
              '[LeavesStore] applyLeave OK id=${existing.id} (from list)',
            );
            return existing;
          }
          if (created.id.isNotEmpty) {
            _requests.insert(0, created);
            await _persistCache();
            notifyListeners();
            AppLogger.info(
              '[LeavesStore] applyLeave OK id=${created.id} (from response)',
            );
            return created;
          }
        }

        for (final request in _requests) {
          if (beforeIds.contains(request.id)) continue;
          final sameType = request.typeId == typeId ||
              (type != null &&
                  request.typeName.toLowerCase() == type.name.toLowerCase());
          final sameDates = request.startDate.year == startDate.year &&
              request.startDate.month == startDate.month &&
              request.startDate.day == startDate.day &&
              request.endDate.year == endDate.year &&
              request.endDate.month == endDate.month &&
              request.endDate.day == endDate.day;
          if (sameType || sameDates) {
            AppLogger.info(
              '[LeavesStore] applyLeave OK id=${request.id} (matched after refresh)',
            );
            return request;
          }
        }
        for (final request in _requests) {
          if (!beforeIds.contains(request.id)) {
            AppLogger.info(
              '[LeavesStore] applyLeave OK id=${request.id} (new after refresh)',
            );
            return request;
          }
        }

        // HTTP success with message-only body — still treat as submitted.
        final optimistic = LeaveRequest(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          typeId: typeId,
          typeName: type?.name ?? typeId,
          startDate: DateTime(startDate.year, startDate.month, startDate.day),
          endDate: DateTime(endDate.year, endDate.month, endDate.day),
          status: LeaveRequestStatus.pending,
          note: trimmedNote,
          createdAt: DateTime.now(),
          documentName: documentName,
          timeline: [
            LeaveTimelineEvent(
              id: 'local_requested',
              kind: LeaveTimelineKind.requested,
              at: DateTime.now(),
            ),
          ],
        );
        _requests.insert(0, optimistic);
        await _persistCache();
        notifyListeners();
        AppLogger.info(
          '[LeavesStore] applyLeave OK (HTTP success, message-only) '
          'localId=${optimistic.id} message=${response.message ?? ''}',
        );
        return optimistic;
      } catch (e, st) {
        final apiError = ApiError.fromException(e);
        if (apiError.type == ApiErrorType.network ||
            apiError.type == ApiErrorType.timeout) {
          AppLogger.info(
            '[LeavesStore] applyLeave network fail → queueing offline',
          );
          return _enqueueApply(
            typeId: typeId,
            typeName: type?.name ?? typeId,
            startDate: startDate,
            endDate: endDate,
            note: trimmedNote,
            documentName: documentName,
          );
        }
        lastError = apiError.message;
        AppLogger.error('LeavesStore', 'applyLeave', e, stackTrace: st);
        return null;
      }
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<LeaveRequest?> updateLeave({
    required String requestId,
    required String typeId,
    required DateTime startDate,
    required DateTime endDate,
    required String note,
    String? documentName,
    bool clearDocument = false,
  }) async {
    final existing = requestById(requestId);
    if (existing == null || !existing.isPending) return existing;

    isSubmitting = true;
    lastError = null;
    lastSuccessMessage = null;
    notifyListeners();
    try {
      final type = typeById(typeId);
      final trimmedNote = note.trim();
      final resolvedDoc = clearDocument ? null : documentName;
      final online = await ConnectivityService.isConnected();

      // Local queued leave: update memory + queue row, no API yet.
      if (existing.isLocal || !online) {
        return _enqueueUpdate(
          requestId: requestId,
          existing: existing,
          typeId: typeId,
          typeName: type?.name ?? existing.typeName,
          startDate: startDate,
          endDate: endDate,
          note: trimmedNote,
          documentName: resolvedDoc,
        );
      }

      try {
        final response = await _service.applyLeave(
          typeId: typeId,
          typeName: type?.name,
          startDate: startDate,
          endDate: endDate,
          note: trimmedNote,
          documentName: resolvedDoc,
          leaveId: requestId,
        );
        if (!response.success) {
          lastError = response.message ??
              response.firstFieldMessage ??
              'Failed to update leave';
          return null;
        }
        lastSuccessMessage = response.message;
        await refresh();
        return requestById(requestId) ?? response.data;
      } catch (e, st) {
        final apiError = ApiError.fromException(e);
        if (apiError.type == ApiErrorType.network ||
            apiError.type == ApiErrorType.timeout) {
          return _enqueueUpdate(
            requestId: requestId,
            existing: existing,
            typeId: typeId,
            typeName: type?.name ?? existing.typeName,
            startDate: startDate,
            endDate: endDate,
            note: trimmedNote,
            documentName: resolvedDoc,
          );
        }
        lastError = apiError.message;
        AppLogger.error('LeavesStore', 'updateLeave', e, stackTrace: st);
        return null;
      }
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<LeaveRequest> _enqueueApply({
    required String typeId,
    required String typeName,
    required DateTime startDate,
    required DateTime endDate,
    required String note,
    String? documentName,
  }) async {
    final now = DateTime.now();
    final localId = 'local_${now.millisecondsSinceEpoch}';
    final optimistic = LeaveRequest(
      id: localId,
      typeId: typeId,
      typeName: typeName,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day),
      status: LeaveRequestStatus.pending,
      note: note,
      createdAt: now,
      documentName: documentName,
      timeline: [
        LeaveTimelineEvent(
          id: '${localId}_requested',
          kind: LeaveTimelineKind.requested,
          at: now,
        ),
      ],
    );

    final queued = await _queue.enqueue(
      _userId,
      LeaveQueuedAction(
        localId: localId,
        action: LeaveQueueActionType.apply,
        typeId: typeId,
        typeName: typeName,
        startDate: optimistic.startDate,
        endDate: optimistic.endDate,
        note: note,
        documentName: documentName,
        createdAt: now,
      ),
    );
    if (!queued) {
      lastError = "Couldn't save this leave locally. Please try again.";
      throw StateError(lastError!);
    }

    _requests.insert(0, optimistic);
    lastSuccessMessage = 'Leave request submitted';
    await _persistCache();
    notifyListeners();
    AppLogger.info('[LeavesStore] applyLeave QUEUED localId=$localId');
    return optimistic;
  }

  Future<LeaveRequest> _enqueueUpdate({
    required String requestId,
    required LeaveRequest existing,
    required String typeId,
    required String typeName,
    required DateTime startDate,
    required DateTime endDate,
    required String note,
    String? documentName,
  }) async {
    // Keep the same list id so detail sheets keep resolving the request.
    final queueLocalId =
        existing.isLocal ? existing.id : 'upd_$requestId';
    final updated = existing.copyWith(
      typeId: typeId,
      typeName: typeName,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day),
      note: note,
      documentName: documentName,
      clearDocument: documentName == null,
    );

    final queued = await _queue.enqueue(
      _userId,
      LeaveQueuedAction(
        localId: queueLocalId,
        action: existing.isLocal
            ? LeaveQueueActionType.apply
            : LeaveQueueActionType.update,
        typeId: typeId,
        typeName: typeName,
        startDate: updated.startDate,
        endDate: updated.endDate,
        note: note,
        documentName: documentName,
        leaveId: existing.isLocal ? null : requestId,
        createdAt: DateTime.now(),
      ),
    );
    if (!queued) {
      lastError = "Couldn't save this leave locally. Please try again.";
      throw StateError(lastError!);
    }

    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index >= 0) {
      _requests[index] = updated;
    } else {
      _requests.insert(0, updated);
    }
    lastSuccessMessage = 'Leave request submitted';
    await _persistCache();
    notifyListeners();
    return updated;
  }

  /// Flushes queued leave applies/updates once the device is online.
  Future<void> syncPendingApplies() {
    final existing = _syncInFlight;
    if (existing != null) return existing;
    final future = _doSyncPendingApplies();
    _syncInFlight = future;
    return future.whenComplete(() {
      if (identical(_syncInFlight, future)) _syncInFlight = null;
    });
  }

  Future<void> _doSyncPendingApplies() async {
    final userId = _userId;
    if (userId.isEmpty) return;
    final online = await ConnectivityService.isConnected();
    if (!online) return;

    final pending = await _queue.getPending(userId);
    if (pending.isEmpty) return;

    AppLogger.info('[LeavesStore] sync start count=${pending.length}');
    var anySuccess = false;

    for (final action in pending) {
      try {
        final response = await _service.applyLeave(
          typeId: action.typeId,
          typeName: action.typeName,
          startDate: action.startDate,
          endDate: action.endDate,
          note: action.note,
          documentName: action.documentName,
          leaveId: action.action == LeaveQueueActionType.update
              ? action.leaveId
              : null,
        );
        final code = response.statusCode;
        if (!response.success || (code != null && code >= 400)) {
          // Business rejection — drop the queue item so we don't retry forever.
          AppLogger.info(
            '[LeavesStore] sync drop ${action.localId}: '
            '${response.message ?? response.firstFieldMessage}',
          );
              await _queue.remove(userId, action.localId);
          _removeLocalAfterSync(action);
          continue;
        }

        await _queue.remove(userId, action.localId);
        _removeLocalAfterSync(action);
        anySuccess = true;
        AppLogger.info('[LeavesStore] sync OK ${action.localId}');
      } catch (e, st) {
        final apiError = ApiError.fromException(e);
        if (apiError.type == ApiErrorType.network ||
            apiError.type == ApiErrorType.timeout) {
          AppLogger.info(
            '[LeavesStore] sync paused (network) at ${action.localId}',
          );
          break;
        }
        // Non-network error: drop to avoid infinite retry.
        AppLogger.error(
          'LeavesStore',
          'syncPendingApplies',
          e,
          stackTrace: st,
        );
        await _queue.remove(userId, action.localId);
        _removeLocalAfterSync(action);
      }
    }

    if (anySuccess) {
      await refresh();
      await ensureHolidaysLoaded();
    } else {
      await _persistCache();
      notifyListeners();
    }
  }

  void _removeLocalAfterSync(LeaveQueuedAction action) {
    if (action.action == LeaveQueueActionType.apply) {
      _requests.removeWhere((r) => r.id == action.localId);
      return;
    }
    // Updates keep the server id in memory; refresh will replace it.
  }

  /// No employee cancel/delete endpoint is declared; returns false.
  Future<bool> deleteLeave(String requestId) async {
    // Offline-queued local apply can still be cancelled before sync.
    if (requestId.startsWith('local_')) {
      final userId = _userId;
      _requests.removeWhere((r) => r.id == requestId);
      if (userId.isNotEmpty) {
        await _queue.remove(userId, requestId);
        await _persistCache();
      }
      notifyListeners();
      return true;
    }
    lastError = 'Cancel leave is not available from the API yet.';
    notifyListeners();
    return false;
  }

  @visibleForTesting
  void debugReplace({
    List<LeaveTypeInfo>? types,
    List<LeaveRequest>? requests,
    List<LeaveHoliday>? holidays,
    String? quotaResetLabel,
    LeavesService? service,
  }) {
    if (types != null) {
      _types
        ..clear()
        ..addAll(types);
    }
    if (requests != null) {
      _requests
        ..clear()
        ..addAll(requests);
    }
    if (holidays != null) {
      _holidays
        ..clear()
        ..addAll(holidays);
      _holidaysLoaded = true;
    }
    if (quotaResetLabel != null) this.quotaResetLabel = quotaResetLabel;
    _serviceOverride = service;
    _loadedOnce = true;
    notifyListeners();
  }
}
