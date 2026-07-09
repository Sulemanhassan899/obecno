import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final Connectivity _connectivity = Connectivity();

  static final _controller = StreamController<bool>.broadcast();

  static Stream<bool> get stream => _controller.stream;

  static StreamSubscription? _subscription;

  static void start() {
    _subscription?.cancel();

    _subscription = _connectivity.onConnectivityChanged.listen((result) async {
      final hasConnection = result != ConnectivityResult.none;
      _controller.add(hasConnection);
    });
  }

  static void stop() {
    _subscription?.cancel();
  }

  static Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
