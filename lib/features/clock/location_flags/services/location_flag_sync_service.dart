import 'dart:async';

import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/repositories/location_flag_repository.dart';
import 'package:obecno/shared/location/service/attendance_connectivity_service.dart';

class LocationFlagSyncService {
  LocationFlagSyncService({
    required LocationFlagRepository repository,
    required ApiClient apiClient,
    required AttendanceConnectivityService connectivity,
    required String? Function() employeeIdProvider,
    required int Function() sessionEpochProvider,
  }) : _repository = repository,
       _apiClient = apiClient,
       _connectivity = connectivity,
       _employeeIdProvider = employeeIdProvider,
       _sessionEpochProvider = sessionEpochProvider;

  final LocationFlagRepository _repository;
  final ApiClient _apiClient;
  final AttendanceConnectivityService _connectivity;
  final String? Function() _employeeIdProvider;
  final int Function() _sessionEpochProvider;

  StreamSubscription<bool>? _subscription;
  bool _syncing = false;

  void startListening() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((online) {
      if (online) unawaited(syncPending());
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> syncPending() async {
    if (_syncing) return;
    final employeeId = _employeeIdProvider();
    if (employeeId == null || employeeId.isEmpty) return;
    if (!await _connectivity.isOnline()) return;

    final epoch = _sessionEpochProvider();
    _syncing = true;
    try {
      final pending = await _repository.pending(employeeId);
      for (final record in pending) {
        if (_sessionEpochProvider() != epoch) break;
        if (_employeeIdProvider() != employeeId) break;
        await _send(record);
      }
    } catch (e, st) {
      AppLogger.error('LocationFlagSync', 'syncPending', e, stackTrace: st);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _send(LocationFlagRecord record) async {
    await _repository.markSyncing(record);
    try {
      final response = await _apiClient.post(
        EmployeeApiEndpoints.attendanceLocationFlags,
        data: record.toSyncPayload(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _repository.markSynced(record);
        return;
      }
      await _repository.markFailed(record);
    } catch (e, st) {
      AppLogger.error('LocationFlagSync', 'send', e, stackTrace: st);
      await _repository.markFailed(record);
    }
  }

  void dispose() {
    stopListening();
  }
}
