import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:obecno/demo/monotonic_clock/clocks/demo_clocks.dart';
import 'package:obecno/demo/monotonic_clock/domain/demo_time_models.dart';
import 'package:obecno/demo/monotonic_clock/services/demo_employee_clock_bridge.dart';
import 'package:obecno/demo/monotonic_clock/services/demo_time_store.dart';
import 'package:obecno/demo/monotonic_clock/services/trusted_time_session.dart';
import 'package:obecno/features/auth/data/models/auth_user_model.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DemoClockMode { live, simulated }

/// UI-facing controller. Live mode uses the device monotonic clock and
/// the logged-in employee. Simulated mode lets you jump time to test
/// scenarios without changing emulator settings.
class MonotonicClockDemoController extends ChangeNotifier
    with WidgetsBindingObserver {
  MonotonicClockDemoController({
    TrustedTimeSession? session,
    DemoClockMode mode = DemoClockMode.live,
  })  : _injectedSession = session,
        _mode = mode;

  final TrustedTimeSession? _injectedSession;

  late TrustedTimeSession _session;
  AuthProvider? _auth;
  late AdjustableMonotonicClock _mono;
  late AdjustableWallClock _wall;
  FakeMonotonicClock? _fakeMono;
  FakeWallClock? _fakeWall;
  DemoClockMode _mode;
  bool _online = true;
  bool _ready = false;
  String? _statusMessage;
  TrustedAttendanceEvent? _lastEvent;
  Timer? _ticker;
  AppLifecycleState? _lifecycle;
  bool _skipNextResumeAppOpen = false;

  static final DateTime simulatedStart = DateTime(2026, 8, 30, 9, 0);

  DemoClockMode get mode => _mode;
  bool get isSimulated => _mode == DemoClockMode.simulated;
  bool get online => _online;
  bool get ready => _ready;
  String? get statusMessage => _statusMessage;
  TrustedAttendanceEvent? get lastEvent => _lastEvent;
  TrustedTimeSession get session => _session;

  AuthUserModel? get employee => _auth?.user;
  bool get isEmployeeLoggedIn => _auth?.isAuthenticated == true;
  bool get canPunch =>
      _ready && snapshot.canIssueAuthoritativeTime;

  TrustedTimeSnapshot get snapshot =>
      _session.currentSnapshot(networkOnline: _online);

  List<TrustedAttendanceEvent> get history => _session.events;

  List<TrustedAttendanceEvent> get pendingSync => _session.pendingSync;

  DateTime? get checkInTime => _latestOf(DemoAttendanceEventType.checkIn);

  DateTime? get breakInTime => _latestOf(DemoAttendanceEventType.breakIn);

  DateTime? get breakOutTime => _latestOf(DemoAttendanceEventType.breakOut);

  DateTime? get checkOutTime => _latestOf(DemoAttendanceEventType.checkOut);

  DateTime? _latestOf(DemoAttendanceEventType type) {
    for (final event in _session.events) {
      if (event.type == type) return event.authoritativeTime;
    }
    return null;
  }

  Future<void> init({AuthProvider? auth}) async {
    _auth = auth;
    _auth?.addListener(_onAuthChanged);

    final injected = _injectedSession;
    if (injected != null) {
      _session = injected;
    } else if (_mode == DemoClockMode.simulated) {
      await _startSimulatedSession();
    } else {
      _mono = AdjustableMonotonicClock(const SystemMonotonicClock());
      _wall = AdjustableWallClock(const SystemWallClock());
      _session = TrustedTimeSession(
        monotonicClock: _mono,
        wallClock: _wall,
        store: PrefsDemoTimeStore(await SharedPreferences.getInstance()),
      );
      await _session.restore();
      await _bindEmployee();
    }

    _ready = true;
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _bindEmployee() async {
    final user = _auth?.user;
    if (_auth?.isAuthenticated != true || user == null) {
      _statusMessage = 'Log in as an employee, then open this demo.';
      return;
    }

    await DemoEmployeeClockBridge.ensureLogin(userId: user.id);
    await _session.restore();

    if (_session.sessionActive) {
      _skipNextResumeAppOpen = true;
      await _session.recordAppOpen(reason: 'demo_open');
      _statusMessage =
          'Using logged-in employee ${user.name}. Login timestamp kept.';
    }
  }

  String get _employeeSessionId {
    final id = _auth?.user?.id;
    return id == null ? 'emp_demo' : DemoEmployeeClockBridge.sessionIdFor(id);
  }

  Future<void> _startSimulatedSession({
    DateTime? wall,
    Duration? monotonic,
  }) async {
    _fakeMono = FakeMonotonicClock(monotonic ?? const Duration(hours: 8));
    _fakeWall = FakeWallClock(wall ?? simulatedStart);
    _mono = AdjustableMonotonicClock(_fakeMono!);
    _wall = AdjustableWallClock(_fakeWall!);
    _session = TrustedTimeSession(
      monotonicClock: _mono,
      wallClock: _wall,
      store: InMemoryDemoTimeStore(),
    );
    await _session.login(sessionId: _employeeSessionId);
    _skipNextResumeAppOpen = true;
  }

  Future<void> setMode(DemoClockMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    _lastEvent = null;
    if (mode == DemoClockMode.simulated) {
      await _startSimulatedSession();
      _statusMessage =
          'SIMULATED clocks. Login set to 09:00 AM. Use CHANGE TIME to test scenarios.';
    } else {
      _fakeMono = null;
      _fakeWall = null;
      _mono = AdjustableMonotonicClock(const SystemMonotonicClock());
      _wall = AdjustableWallClock(const SystemWallClock());
      _session = TrustedTimeSession(
        monotonicClock: _mono,
        wallClock: _wall,
        store: PrefsDemoTimeStore(await SharedPreferences.getInstance()),
      );
      await _session.restore();
      await _bindEmployee();
      _statusMessage =
          'LIVE device clocks. CHANGE TIME still works — it offsets this demo without changing the emulator clock.';
    }
    notifyListeners();
  }

  /// Real elapsed time: monotonic and wall move together.
  void advanceActual(Duration duration) {
    _mono.advance(duration);
    _wall.advance(duration);
    _statusMessage = 'Actual time advanced by $duration (monotonic + wall).';
    notifyListeners();
  }

  /// Phone wall clock only — monotonic keeps going.
  void shiftPhoneWallClock(Duration duration) {
    _wall.advance(duration);
    _statusMessage =
        'Phone wall clock shifted by $duration. Monotonic unchanged.';
    notifyListeners();
  }

  void setPhoneWallClock(DateTime value) {
    _wall.setNow(value);
    _statusMessage = 'Phone wall clock set to $value. Monotonic unchanged.';
    notifyListeners();
  }

  /// Sets phone time to [hour]:[minute] on the current demo day.
  void setPhoneTo({required int hour, int minute = 0}) {
    final raw = _wall.rawNow();
    setPhoneWallClock(DateTime(raw.year, raw.month, raw.day, hour, minute));
  }

  void simulateReboot() {
    _mono.simulateReboot(elapsed: const Duration(seconds: 12));
    _statusMessage =
        'Reboot simulated. Monotonic reset. Attendance timestamps refused until a new login.';
    notifyListeners();
  }

  void _onAuthChanged() {
    unawaited(_handleAuthChanged());
  }

  Future<void> _handleAuthChanged() async {
    if (isSimulated) return;
    if (_auth?.isAuthenticated != true) {
      await DemoEmployeeClockBridge.ensureLoggedOut();
      await _session.restore();
      _statusMessage = 'Employee logged out. Login timestamp cleared.';
      notifyListeners();
      return;
    }
    await _bindEmployee();
    notifyListeners();
  }

  Future<void> recordAppOpen() async {
    final open = await _session.recordAppOpen(reason: 'manual');
    _statusMessage = open == null
        ? 'App-open skipped — employee must be logged in.'
        : 'App-open timestamp recorded. Login timestamp unchanged.';
    notifyListeners();
  }

  Future<void> recordAppClose() async {
    final close = await _session.recordAppClose(reason: 'manual');
    _statusMessage = close == null
        ? 'App-close skipped — employee must be logged in.'
        : 'App-close timestamp recorded. Login timestamp unchanged.';
    notifyListeners();
  }

  Future<void> resetEvents() async {
    await _session.resetEventsOnly();
    _lastEvent = null;
    _statusMessage = 'Events cleared. Employee login timestamp kept.';
    notifyListeners();
  }

  void setOnline(bool value) {
    _online = value;
    _statusMessage = value ? 'Network: ONLINE' : 'Network: OFFLINE';
    notifyListeners();
  }

  Future<RecordEventResult> record(DemoAttendanceEventType type) async {
    final result = await _session.recordEvent(
      type: type,
      networkOnline: _online,
    );
    if (result.isOk) {
      final event = result.event!;
      _lastEvent = event;
      _statusMessage =
          '${event.type.logName}  ${event.comparison.label}  '
          'sent ${event.timeSentToServer}';
    } else {
      _statusMessage = result.error;
    }
    notifyListeners();
    return result;
  }

  Future<void> syncNow() async {
    if (!_online) {
      _statusMessage = 'Still offline — queued events wait for network.';
      notifyListeners();
      return;
    }
    final result = await _session.syncPending();
    if (result.synced.isEmpty) {
      _statusMessage = 'Nothing to sync.';
    } else {
      _statusMessage =
          'Synced ${result.synced.length} event(s) with original timestamps.';
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _lifecycle;
    _lifecycle = state;

    final closing = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (closing && previous == AppLifecycleState.resumed) {
      unawaited(_onBackground());
      return;
    }

    if (state == AppLifecycleState.resumed &&
        previous != null &&
        previous != AppLifecycleState.resumed) {
      if (_skipNextResumeAppOpen) {
        _skipNextResumeAppOpen = false;
        return;
      }
      unawaited(_onForeground());
    }
  }

  Future<void> _onForeground() async {
    await _session.recordAppOpen(reason: 'foreground');
    notifyListeners();
  }

  Future<void> _onBackground() async {
    await _session.recordAppClose(reason: 'background');
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _auth?.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
