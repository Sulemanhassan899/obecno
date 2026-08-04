import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkChecker {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkCheckerImpl implements NetworkChecker {
  NetworkCheckerImpl({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

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
