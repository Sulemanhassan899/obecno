import 'dart:async';

class ApiCancelToken {
  ApiCancelToken() : createdAt = DateTime.now();

  bool _isCancelled = false;
  String? _reason;
  final Completer<void> _cancelled = Completer<void>();

  final DateTime createdAt;

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  /// Completes the instant [cancel] is called. Race a request against this
  /// (rather than polling [isCancelled]) to abandon it immediately instead
  /// of waiting for the next poll point -- e.g. mid backoff-sleep.
  Future<void> get whenCancelled => _cancelled.future;

  void cancel([String? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason;
    _cancelled.complete();
  }
}
