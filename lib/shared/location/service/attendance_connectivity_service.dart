// NOTE: adjust this import to wherever `network_checker.dart` actually
// lives in the project (it wasn't attached with a package path). It's
// the existing `NetworkChecker`/`NetworkCheckerImpl` abstraction that
// already wraps `connectivity_plus` -- reused here rather than
// duplicated, per the "don't duplicate functionality" rule.
import 'package:Obecno/core/services/network_checker.dart';

abstract class AttendanceConnectivityService {
  Future<bool> isOnline();
  Stream<bool> get onConnectivityChanged;
}

/// Deliberately does NOT reimplement connectivity_plus logic -- it just
/// adapts the existing `NetworkChecker` to the method-contract shape
/// `AttendanceRepository`/`SyncService` expect (`isOnline()` +
/// `onConnectivityChanged`).
class AttendanceConnectivityServiceImpl implements AttendanceConnectivityService {
  AttendanceConnectivityServiceImpl({NetworkChecker? networkChecker})
      : _networkChecker = networkChecker ?? NetworkCheckerImpl();

  final NetworkChecker _networkChecker;

  @override
  Future<bool> isOnline() => _networkChecker.isConnected;

  @override
  Stream<bool> get onConnectivityChanged => _networkChecker.onConnectivityChanged;
}
