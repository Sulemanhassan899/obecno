

import 'dart:async';
import 'dart:convert';

import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/shared/location/data/queue_model.dart';
import 'package:Obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:Obecno/shared/location/service/local_queue_service.dart';

import '../repositories/clock_attendance_repository.dart';


enum SyncState { idle, syncing, success, failure }

class SyncService {
  SyncService(
    this._repository,
    this._connectivityService,
    this._queueService, {
    int? Function()? sessionEpochProvider,
    ApiCancelToken? Function()? cancelTokenProvider,
    String? Function()? userIdProvider,
  }) : _sessionEpochProvider = sessionEpochProvider,
       _cancelTokenProvider = cancelTokenProvider,
       _userIdProvider = userIdProvider;
  static const int maxRetries = 5;

  static const Duration _perCallTimeout = Duration(seconds: 10);

  static const Duration _fullSyncTimeout = Duration(seconds: 60);

  static const List<Duration> _retryBackoff = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  // Fix (Issue 4): when a sync pass is forced back to idle by
  // _fullSyncTimeout, this is how long we wait before automatically
  // re-triggering syncPendingData() for the remaining queue, instead of
  // relying solely on the next connectivity-changed event or app restart.
  static const Duration _stuckRetryDelay = Duration(seconds: 30);

  final AttendanceRepository _repository;
  final AttendanceConnectivityService _connectivityService;
  final LocalQueueService _queueService;

  final int? Function()? _sessionEpochProvider;

  final ApiCancelToken? Function()? _cancelTokenProvider;

  final String? Function()? _userIdProvider;

  StreamSubscription<bool>? _subscription;

  // Fix (Issue 4): at most one pending "retry after stuck timeout" is ever
  // scheduled -- any existing timer is cancelled before a new one is set,
  // so this cannot accumulate into overlapping/duplicate retry loops.
  Timer? _stuckRetryTimer;

  SyncState _state = SyncState.idle;
  SyncState get state => _state;

  void Function(String requestId, String action, String message)?
  onQueuedItemSynced;

  void Function()? onSyncCompleted;

  void Function(SyncState state)? onStateChanged;

  void _setState(SyncState next, [int? epoch]) {
    if (_state == next) return;
    _state = next;
    // Fix (Issue 1): previously this check was computed but never used, so
    // onStateChanged still fired for a session that had already ended --
    // e.g. User B briefly seeing a "syncing" state left over from User A's
    // trailing sync pass. Now a stale-session state change updates _state
    // internally (so the state machine itself stays consistent) but is not
    // broadcast to whichever screen/session is currently listening.
    final isStale = epoch != null && _sessionEpochProvider != null &&
        _sessionEpochProvider() != epoch;
    if (isStale) return;
    onStateChanged?.call(next);
  }

  bool _staleSession(int? startEpoch) =>
      _sessionEpochProvider != null && _sessionEpochProvider() != startEpoch;

  void startListening() {
    _subscription?.cancel();
    _subscription = _connectivityService.onConnectivityChanged.listen((online) {
      if (online) {
        unawaited(syncPendingData());
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
  void _logEvent(
    String event, {
    required int queueSize,
    required int processedCount,
    required int failedCount,
    String? eventId,
    String? error,
  }) {
    final entry = <String, dynamic>{
      'event': event,
      'userId': _userIdProvider?.call(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'queueSize': queueSize,
      'processedCount': processedCount,
      'failedCount': failedCount,
      if (eventId != null) 'eventId': eventId,
      if (error != null) 'error': error,
    };
    try {
      AppLogger.info(jsonEncode(entry));
    } catch (_) {
      // Never let a logging failure affect sync correctness.
      AppLogger.info('[SyncService] $event (log serialization failed)');
    }
  }

  Future<void> syncPendingData() async {
    if (_state == SyncState.syncing) {
      AppLogger.info('[SyncService] sync already in progress, skipping');
      return;
    }
    final epochAtStart = _sessionEpochProvider?.call();
    _setState(SyncState.syncing, epochAtStart);

    final stopwatch = Stopwatch()..start();
    var syncedCount = 0;
    var failedCount = 0;
    var stuck = false;

    try {
      final pending = await _queueService.getPending();
      final queueSize = pending.length;

      _logEvent(
        'SYNC_START',
        queueSize: queueSize,
        processedCount: 0,
        failedCount: 0,
      );

      for (final item in pending) {
        if (_staleSession(epochAtStart)) {
          AppLogger.info('[SyncService] session changed mid-sync, aborting remaining items');
          break;
        }

        if (stopwatch.elapsed >= _fullSyncTimeout) {
          stuck = true;
          break;
        }

        final outcome = await _sendItemWithRetry(
          item,
          epochAtStart: epochAtStart,
          queueSize: queueSize,
          processedCount: syncedCount + failedCount,
        );

        if (outcome == _ItemOutcome.cancelled) {
          break;
        }

        if (outcome is _ItemSuccess) {
          await _queueService.markSynced(item.id);
          await _queueService.resetFailure(item.id);
          syncedCount++;
          _logEvent(
            'SYNC_ITEM',
            queueSize: queueSize,
            processedCount: syncedCount + failedCount,
            failedCount: failedCount,
            eventId: item.payload.requestId,
          );
      
          if (!_staleSession(epochAtStart)) {
            onQueuedItemSynced?.call(
              item.payload.requestId,
              item.payload.action,
              outcome.message ?? '',
            );
          }
          continue;
        }

        failedCount++;
        final failure = outcome as _ItemFailure;
        _logEvent(
          'SYNC_FAILURE',
          queueSize: queueSize,
          processedCount: syncedCount + failedCount,
          failedCount: failedCount,
          eventId: item.payload.requestId,
          error: failure.error.toString(),
        );

        if (!_isRetryable(failure.error)) {
          await _queueService.markDeadLetter(item.id);
        } else {
          final attempts = await _queueService.recordFailure(item.id);
          if (attempts >= maxRetries) {
            await _queueService.markDeadLetter(item.id);
          }
        }
      }

      _setState(
        failedCount > 0 ? SyncState.failure : SyncState.success,
        epochAtStart,
      );

      if (stuck) {
        _logEvent(
          'SYNC_FAILURE',
          queueSize: queueSize,
          processedCount: syncedCount + failedCount,
          failedCount: failedCount,
          error: 'sync exceeded ${_fullSyncTimeout.inSeconds}s budget, '
              'forced back to idle; remaining items retried next pass',
        );
        // Fix (Issue 4): don't rely solely on the next connectivity-changed
        // event or app restart to pick the queue back up -- schedule one.
        _scheduleStuckRetry(epochAtStart);
      } else {
        _logEvent(
          'SYNC_SUCCESS',
          queueSize: queueSize,
          processedCount: syncedCount + failedCount,
          failedCount: failedCount,
        );
      }

      if (syncedCount > 0 && !_staleSession(epochAtStart)) {
        onSyncCompleted?.call();
      }
    } catch (e) {
      _logEvent(
        'SYNC_FAILURE',
        queueSize: 0,
        processedCount: syncedCount + failedCount,
        failedCount: failedCount,
        error: e.toString(),
      );
    } finally {
      stopwatch.stop();
      _setState(SyncState.idle, epochAtStart);
    }
  }

  // Fix (Issue 4): schedules a single automatic follow-up sync after a
  // stuck/timed-out pass. Cancelling any existing timer before scheduling a
  // new one keeps this to at most one pending retry -- repeated timeouts
  // reschedule the same single timer rather than piling up new ones, so
  // this cannot spiral into an unbounded retry loop. The retry respects the
  // session it was scheduled under: if the user has logged out or a
  // different user has logged in by the time it fires, it does nothing.
  void _scheduleStuckRetry(int? epochAtStart) {
    _stuckRetryTimer?.cancel();
    _stuckRetryTimer = Timer(_stuckRetryDelay, () {
      _stuckRetryTimer = null;
      if (_staleSession(epochAtStart)) return;
      unawaited(syncPendingData());
    });
  }

  static bool _isRetryable(Object error) =>
      error is! AttendanceBusinessException && error is! AttendanceAuthException;

  Future<_ItemOutcome> _sendItemWithRetry(
    QueueModel item, {
    required int? epochAtStart,
    required int queueSize,
    required int processedCount,
  }) async {
    Object lastError = StateError('unknown sync failure');

    for (var attempt = 0; attempt <= _retryBackoff.length; attempt++) {
      if (_staleSession(epochAtStart)) return _ItemOutcome.cancelled;

      try {
        final message = await _repository
            .sendQueuedPayload(
              item.payload,
              cancelToken: _cancelTokenProvider?.call(),
            )
            .timeout(_perCallTimeout);
        return _ItemSuccess(message);
      } on AttendanceCancelledException {
        return _ItemOutcome.cancelled;
      } catch (e, st) {
        lastError = e;
        AppLogger.error(
          'SyncService',
          'syncPendingData (item ${item.id}, attempt ${attempt + 1})',
          e,
          stackTrace: st,
        );

        final isLastAttempt = attempt == _retryBackoff.length;
        if (isLastAttempt || !_isRetryable(e)) break;

        await Future.delayed(_retryBackoff[attempt]);
      }
    }

    return _ItemFailure(lastError);
  }

  Future<int> getDeadLetterCount() => _queueService.getDeadLetterCount();

  Future<bool> retryDeadLetterItem(int id) async {
    final restored = await _queueService.retryDeadLetter(id);
    if (restored) {
      unawaited(syncPendingData());
    }
    return restored;
  }

  void dispose() {
    _stuckRetryTimer?.cancel();
    _stuckRetryTimer = null;
    stopListening();
  }
}
sealed class _ItemOutcome {
  const _ItemOutcome();
  static const cancelled = _ItemCancelled();
}

class _ItemSuccess extends _ItemOutcome {
  const _ItemSuccess(this.message);
  final String? message;
}

class _ItemFailure extends _ItemOutcome {
  const _ItemFailure(this.error);
  final Object error;
}

class _ItemCancelled extends _ItemOutcome {
  const _ItemCancelled();
}