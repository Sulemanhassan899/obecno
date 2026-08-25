import 'package:obecno/core/services/network_checker.dart';

abstract class AttendanceConnectivityService {
  Future<bool> isOnline();
  Stream<bool> get onConnectivityChanged;
}

class AttendanceConnectivityServiceImpl
    implements AttendanceConnectivityService {
  AttendanceConnectivityServiceImpl({NetworkChecker? networkChecker})
    : _networkChecker = networkChecker ?? NetworkCheckerImpl();

  final NetworkChecker _networkChecker;

  @override
  Future<bool> isOnline() => _networkChecker.isConnected;

  @override
  Stream<bool> get onConnectivityChanged =>
      _networkChecker.onConnectivityChanged;
}
