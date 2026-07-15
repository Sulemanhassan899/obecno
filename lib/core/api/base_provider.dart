import 'package:Obecno/core/api/api_response.dart';
import 'package:flutter/foundation.dart';

import './api_cancel_token.dart';

enum ViewStatus { idle, loading, success, error }

/// Common ChangeNotifier scaffolding every feature provider builds on
/// (AttendanceProvider, MonthlyAttendanceProvider, ...). Centralizes:
///
///  - loading / error / data status flags the UI binds to
///  - a single in-flight [ApiCancelToken] per named operation, so rapid
///    double-taps cancel the previous call instead of racing it
///  - a `safeCall` wrapper that repositories' [ApiResponse] plugs into
///    directly, keeping feature providers free of try/catch boilerplate
///
/// FIXED: uses [ApiCancelToken] instead of `package:dio`'s `CancelToken`
/// now that the api layer no longer depends on Dio. Behavior is
/// unchanged — `safeCall` still discards a response if a newer call under
/// the same key superseded it.
abstract class BaseProvider extends ChangeNotifier {
  ViewStatus _status = ViewStatus.idle;
  String? _errorMessage;

  final Map<String, ApiCancelToken> _activeCalls = {};

  ViewStatus get status => _status;
  bool get isLoading => _status == ViewStatus.loading;
  bool get hasError => _status == ViewStatus.error;
  String? get errorMessage => _errorMessage;

  @protected
  void setLoading() {
    _status = ViewStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  @protected
  void setSuccess() {
    _status = ViewStatus.success;
    _errorMessage = null;
    notifyListeners();
  }

  @protected
  void setError(String message) {
    _status = ViewStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  /// Returns a fresh [ApiCancelToken] for [operationKey], cancelling any
  /// previous in-flight call under the same key first. Pass the returned
  /// token into the repository call so a rapid second tap on, say, the
  /// clock-in button discards the stale first request's result instead of
  /// both racing to update state.
  @protected
  ApiCancelToken newCancelToken(String operationKey) {
    _activeCalls[operationKey]?.cancel('Superseded by a newer request.');
    final token = ApiCancelToken();
    _activeCalls[operationKey] = token;
    return token;
  }

  /// Wraps a repository call: flips loading on, awaits the [ApiResponse],
  /// then routes to [onSuccess] or [setError] automatically. Returns
  /// whether the call succeeded, in case the caller needs to chain logic
  /// (e.g. navigate away after a successful clock-in).
  @protected
  Future<bool> safeCall<T>({
    required String operationKey,
    required Future<ApiResponse<T>> Function(ApiCancelToken cancelToken) request,
    required void Function(T data) onSuccess,
    bool guardAgainstDuplicate = true,
  }) async {
    if (guardAgainstDuplicate && isLoading) {
      // A call under a *different* key would set loading too; if stricter
      // per-key duplicate prevention is needed, track a Set<String> of
      // in-flight keys instead of the single global status flag.
      return false;
    }

    setLoading();
    final cancelToken = newCancelToken(operationKey);

    final response = await request(cancelToken);

    if (cancelToken.isCancelled) {
      // A newer call superseded this one; don't overwrite its state.
      return false;
    }

    if (response.success && response.data != null) {
      onSuccess(response.data as T);
      setSuccess();
      return true;
    }

    setError(response.message ?? 'Something went wrong. Please try again.');
    return false;
  }

  void cancelAll() {
    for (final token in _activeCalls.values) {
      if (!token.isCancelled) token.cancel('Provider disposed or reset.');
    }
    _activeCalls.clear();
  }

  @override
  void dispose() {
    cancelAll();
    super.dispose();
  }
}
