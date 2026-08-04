import 'dart:async';
import 'package:Obecno/core/services/network_checker.dart';

class ConnectivityService {
  ConnectivityService._();

  static final NetworkChecker _networkChecker = NetworkCheckerImpl();

  static final _controller = StreamController<bool>.broadcast();

  static Stream<bool> get stream => _controller.stream;

  static StreamSubscription<bool>? _subscription;

  static void start() {
    _subscription?.cancel();

    _subscription = _networkChecker.onConnectivityChanged.listen((
      hasConnection,
    ) {
      _controller.add(hasConnection);
    });
  }

  static void stop() {
    _subscription?.cancel();
  }

  static Future<bool> isConnected() => _networkChecker.isConnected;
}
