import 'package:obecno/core/api/api_response.dart';
import 'package:flutter/foundation.dart';

import './api_cancel_token.dart';

enum ViewStatus { idle, loading, success, error }

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

  @protected
  void resetViewState() {
    _status = ViewStatus.idle;
    _errorMessage = null;
  }

  @protected
  ApiCancelToken newCancelToken(String operationKey) {
    _activeCalls[operationKey]?.cancel('Superseded by a newer request.');
    final token = ApiCancelToken();
    _activeCalls[operationKey] = token;
    return token;
  }

  static const Duration _staleCallTimeout = Duration(seconds: 30);

  @protected
  Future<bool> safeCall<T>({
    required String operationKey,
    required Future<ApiResponse<T>> Function(ApiCancelToken cancelToken)
    request,
    required void Function(T data) onSuccess,
    bool guardAgainstDuplicate = true,
  }) async {
    if (guardAgainstDuplicate) {
      final existing = _activeCalls[operationKey];
      if (existing != null && !existing.isCancelled) {
        final age = DateTime.now().difference(existing.createdAt);
        if (age < _staleCallTimeout) {
          debugPrint(
            '[BaseProvider] "$operationKey" blocked -- another call under '
            'this key is still in flight (age: ${age.inSeconds}s).',
          );
          return false;
        }

        debugPrint(
          '[BaseProvider] "$operationKey" had a stale token '
          '(${age.inSeconds}s old) -- treating as stuck, not blocking.',
        );
      }
    }

    setLoading();
    final cancelToken = newCancelToken(operationKey);
    debugPrint('[BaseProvider] -> "$operationKey" request starting');

    try {
      final response = await request(cancelToken);

      if (cancelToken.isCancelled) {
        debugPrint(
          '[BaseProvider] "$operationKey" superseded/cancelled, skipping.',
        );
        return false;
      }

      if (response.success && response.data != null) {
        debugPrint('[BaseProvider] <- "$operationKey" succeeded');
        onSuccess(response.data as T);
        setSuccess();
        return true;
      }

      debugPrint(
        '[BaseProvider] <- "$operationKey" failed: ${response.message}',
      );
      setError(response.message ?? 'Something went wrong. Please try again.');
      return false;
    } finally {
      if (identical(_activeCalls[operationKey], cancelToken)) {
        _activeCalls.remove(operationKey);
      }
    }
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
