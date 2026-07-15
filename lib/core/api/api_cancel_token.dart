/// Replaces `package:dio`'s `CancelToken` now that the api layer no longer
/// depends on Dio. Semantics are the same as before: it doesn't forcibly
/// abort an in-flight `http` request (the `http` package has no built-in
/// abort primitive), but `BaseProvider.safeCall` already only used the
/// token to check "is this result stale?" after the await — so a rapid
/// second tap still cancels the *previous* call's effect on state, it
/// just doesn't stop the first request's bytes from finishing on the wire.
class ApiCancelToken {
  bool _isCancelled = false;
  String? _reason;

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  void cancel([String? reason]) {
    _isCancelled = true;
    _reason = reason;
  }
}
