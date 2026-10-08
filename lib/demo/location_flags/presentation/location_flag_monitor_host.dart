import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';
import 'package:obecno/demo/location_flags/presentation/location_flag_demo_controller.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/auth/providers/permission_provider.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/location/service/geofence_helper.dart';
import 'package:obecno/shared/location/service/location_provider.dart';

/// Keeps location-flag checks and notifications running on every screen.
class LocationFlagMonitorHost extends StatefulWidget {
  const LocationFlagMonitorHost({super.key, required this.child});

  final Widget child;

  static final LocationFlagDemoController controller =
      LocationFlagDemoController();

  /// Builds policy from backend attendance permissions.
  /// Flag window uses check-in/out ± 1 hour (see [PolicyWindow.visualStartMinutes]).
  static PolicyWindow policyFromPermissions(PermissionProvider permissions) {
    final checkIn = ManagerEmployeePolicy.parseTime(
      _permissionValue(permissions, 'check_in_time'),
    );
    final checkOut = ManagerEmployeePolicy.parseTime(
      _permissionValue(permissions, 'check_out_time'),
    );
    final grace =
        ManagerEmployeePolicy.parseMinutes(
          _permissionValue(permissions, 'grace_period'),
        ) ??
        5;

    // Prefer backend / employee override times. Only fall back to 9–6 when
    // times are missing or checkout is not after check-in on the same day.
    var inMinutes = checkIn == null
        ? 9 * 60
        : checkIn.hour * 60 + checkIn.minute;
    var outMinutes = checkOut == null
        ? 18 * 60
        : checkOut.hour * 60 + checkOut.minute;

    if (outMinutes <= inMinutes) {
      inMinutes = 9 * 60;
      outMinutes = 18 * 60;
    }

    return PolicyWindow(
      checkInMinutes: inMinutes,
      checkOutMinutes: outMinutes,
      graceMinutes: grace < 0 ? 5 : grace,
    );
  }

  /// Prefer attendance section, then any section that carries the key.
  static String? _permissionValue(PermissionProvider permissions, String key) {
    final direct = permissions.valueOf('attendance', key);
    if (direct != null && direct.trim().isNotEmpty) return direct;
    for (final items in permissions.sections.values) {
      for (final item in items) {
        final value = item.value;
        if (item.key == key && value != null && value.trim().isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  static List<AssignedOffice> officesFromContext(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final location = context.read<LocationProvider>();
    final offices = <AssignedOffice>[];
    for (final place in auth.locations) {
      final point = GeoPoint.tryParse(place.latLon);
      if (point == null) continue;
      offices.add(
        AssignedOffice(
          id: place.id,
          name: place.name,
          latitude: point.lat,
          longitude: point.lon,
          radiusMeters: (place.radiusMeters ?? location.radiusMeters)
              .toDouble(),
        ),
      );
    }
    if (offices.isEmpty && location.companyLocation != null) {
      offices.add(
        AssignedOffice(
          id: 'selected',
          name: location.companyLocationName ?? 'Office',
          latitude: location.companyLocation!.lat,
          longitude: location.companyLocation!.lon,
          radiusMeters: location.radiusMeters.toDouble(),
        ),
      );
    }
    return offices;
  }

  /// Pulls latest check-in/out policy from backend and reloads flags without clearing them.
  static Future<void> refreshFromBackend(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final permissions = context.read<PermissionProvider>();
    final userId = auth.user?.id;
    if (userId == null || userId.isEmpty) return;

    await permissions.refresh();
    final checkedIn = await _readCheckedIn();
    await controller.refreshFlags(
      policyWindow: policyFromPermissions(permissions),
      offices: officesFromContext(context),
      checkedIn: checkedIn,
    );
  }

  static Future<bool> _readCheckedIn() async {
    try {
      final month = await bindings.attendanceRepository.loadMonthFromCache(
        DateTime.now(),
      );
      final todayKey = dateKey(DateTime.now());
      AttendanceDay? today;
      for (final day in month?.rawDays ?? const <AttendanceDay>[]) {
        if (dateKey(day.date) == todayKey) today = day;
      }
      return today != null &&
          today.checkIns.isNotEmpty &&
          today.checkIns.length > today.checkOuts.length;
    } catch (_) {
      return false;
    }
  }

  @override
  State<LocationFlagMonitorHost> createState() =>
      _LocationFlagMonitorHostState();
}

class _LocationFlagMonitorHostState extends State<LocationFlagMonitorHost>
    with WidgetsBindingObserver {
  AuthProvider? _auth;
  PermissionProvider? _permissions;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocationFlagMonitorHost.controller.onBeforeTick = _refreshAttendance;
    LocationFlagMonitorHost.controller.init().then((_) {
      if (!mounted) return;
      _bindAuth();
      _bindPermissions();
      _syncAuthSession();
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _permissions?.removeListener(_onPermissionsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LocationFlagMonitorHost.controller.onAppResumed();
      bindings.smartAttendanceService.onAppResumed();
      if (LocationFlagMonitorHost.controller.clockAlive) {
        unawaited(_applyLatestPolicy());
      }
    }
  }

  void _bindAuth() {
    final auth = context.read<AuthProvider>();
    if (identical(_auth, auth)) return;
    _auth?.removeListener(_onAuthChanged);
    _auth = auth;
    _wasAuthenticated =
        auth.isAuthenticated && (auth.user?.id.isNotEmpty ?? false);
    auth.addListener(_onAuthChanged);
  }

  void _bindPermissions() {
    final permissions = context.read<PermissionProvider>();
    if (identical(_permissions, permissions)) return;
    _permissions?.removeListener(_onPermissionsChanged);
    _permissions = permissions;
    permissions.addListener(_onPermissionsChanged);
  }

  void _onAuthChanged() {
    _syncAuthSession();
  }

  void _onPermissionsChanged() {
    if (!LocationFlagMonitorHost.controller.clockAlive) return;
    unawaited(_applyLatestPolicy());
  }

  Future<void> _applyLatestPolicy() async {
    if (!mounted) return;
    _bindPermissions();
    final permissions = _permissions!;
    final next = LocationFlagMonitorHost.policyFromPermissions(permissions);
    final current = LocationFlagMonitorHost.controller.policy;
    if (current.checkInMinutes == next.checkInMinutes &&
        current.checkOutMinutes == next.checkOutMinutes &&
        current.graceMinutes == next.graceMinutes) {
      return;
    }
    await LocationFlagMonitorHost.controller.refreshFlags(
      policyWindow: next,
      offices: LocationFlagMonitorHost.officesFromContext(context),
      checkedIn: await LocationFlagMonitorHost._readCheckedIn(),
    );
  }

  Future<void> _syncAuthSession() async {
    if (!mounted) return;
    _bindAuth();
    _bindPermissions();
    final auth = _auth!;
    final userId = auth.user?.id;
    final loggedIn =
        auth.isAuthenticated && userId != null && userId.isNotEmpty;

    if (!loggedIn) {
      if (_wasAuthenticated || LocationFlagMonitorHost.controller.clockAlive) {
        await LocationFlagMonitorHost.controller.stopFollowing();
      }
      _wasAuthenticated = false;
      return;
    }

    if (_wasAuthenticated && LocationFlagMonitorHost.controller.clockAlive) {
      // Already following — still pick up policy if permissions finished loading.
      await _applyLatestPolicy();
      return;
    }
    _wasAuthenticated = true;
    await _startFollowing(userId);
  }

  Future<void> _startFollowing(String userId) async {
    if (!mounted) return;
    final permissions = context.read<PermissionProvider>();
    // Always rebuild from cache, then refresh network so assigned timings apply.
    await permissions.load();
    if (permissions.checkInTime == null || permissions.checkOutTime == null) {
      await permissions.refresh();
    }
    if (!mounted) return;
    await LocationFlagMonitorHost.controller.followClock(
      employeeId: userId,
      offices: LocationFlagMonitorHost.officesFromContext(context),
      checkedIn: await LocationFlagMonitorHost._readCheckedIn(),
      policyWindow: LocationFlagMonitorHost.policyFromPermissions(permissions),
    );
    bindings.smartAttendanceService.syncWithToggles();
  }

  Future<void> _refreshAttendance() async {
    final checkedIn = await LocationFlagMonitorHost._readCheckedIn();
    final monitor = LocationFlagMonitorHost.controller.monitor;
    if (checkedIn && monitor.phase == AttendancePhase.notCheckedIn) {
      monitor.checkIn();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
