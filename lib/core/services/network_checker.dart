import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps `connectivity_plus` so the rest of the app depends on a single,
/// mockable abstraction instead of the plugin directly (important for
/// unit-testing repositories/providers without a platform channel).
abstract class NetworkChecker {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkCheckerImpl implements NetworkChecker {
  NetworkCheckerImpl({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_hasConnection);
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
