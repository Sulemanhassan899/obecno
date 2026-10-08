import 'package:flutter/foundation.dart';
import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/employee_location_assignment.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/add_location_log.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/all_locations_screen.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/setup_location_map_screen.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/break_timing_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/check_in_out_timing_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/add_members_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/delete_location_dialog.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/working_days_sheet.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/location_deactivated_banner.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key, required this.location});

  final ManagerLocationModel location;

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  late ManagerLocationModel _location;
  LocationSchedule _schedule = LocationSchedule.defaults;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _location = widget.location;
    _schedule = widget.location.policy;
    debugPrint(
      '[LocationStatus] setup.init '
      'id=${_location.id} name=${_location.name} isActive=${_location.isActive}',
    );
    _load();
  }

  void _syncActiveFromProvider() {
    final fromProvider = context.read<ManagerLocationsProvider>().byId(
      _location.id,
    );
    if (fromProvider == null) return;
    if (fromProvider.isActive == _location.isActive) return;
    debugPrint(
      '[LocationStatus] setup.syncFromProvider '
      'id=${_location.id} was=${_location.isActive} now=${fromProvider.isActive}',
    );
    _location = _location.copyWith(isActive: fromProvider.isActive);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await bindings.managerLocationsService.loadLocation(
      locationId: _location.id,
    );
    if (!mounted) return;
    if (!result.success || result.data == null) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
    } else {
      _location = result.data!;
      _schedule = result.data!.policy;
      debugPrint(
        '[LocationStatus] setup.loadLocation '
        'id=${_location.id} apiIsActive=${_location.isActive}',
      );
    }

    final schedule = await bindings.managerLocationsService
        .loadLocationSchedule(locationId: _location.id);
    if (!mounted) return;
    _syncActiveFromProvider();
    setState(() {
      if (schedule.success && schedule.data != null) {
        _schedule = schedule.data!;
        _location = _location.copyWith(schedule: schedule.data);
      }
      _loading = false;
    });
    debugPrint(
      '[LocationStatus] setup.load.done '
      'id=${_location.id} isActive=${_location.isActive}',
    );
  }

  Future<void> _refreshList() {
    return context.read<ManagerLocationsProvider>().refresh();
  }

  void _applySchedule(LocationSchedule? schedule) {
    if (schedule == null || !mounted) return;
    setState(() {
      _schedule = schedule;
      _location = _location.copyWith(schedule: schedule);
    });
  }

  Future<void> _onSetupLocation() async {
    AddLocationLog.dump(
      sheet: 'Set up Location',
      phase: 'sheet open',
      api: 'PUT /manager/locations/${_location.id}',
      apiNeeds: AddLocationLog.updatePinApiNeeds,
      extra: {
        'address': _location.address,
        'latitude': _location.latitude,
        'longitude': _location.longitude,
      },
    );
    final selected = await SetupLocationMapScreen.open(
      context,
      initialAddress: _location.address,
      initialLatitude: _location.latitude,
      initialLongitude: _location.longitude,
      initialRadiusMeters: _location.radiusMeters,
    );
    if (!mounted || selected == null) return;

    setState(() => _busy = true);
    final next = _location.copyWith(
      address: selected.address,
      latitude: selected.latitude,
      longitude: selected.longitude,
      radiusMeters: selected.radiusMeters,
    );
    final result = await bindings.managerLocationsService.updateLocation(
      location: next,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to update location.',
      );
      return;
    }

    setState(() {
      _location = (result.data ?? next).copyWith(
        address: selected.address,
        latitude: selected.latitude,
        longitude: selected.longitude,
        radiusMeters: selected.radiusMeters,
        schedule: _schedule,
      );
    });
    await _refreshList();
    if (!mounted) return;
    ToastHelper.changesSaved(context);
  }

  Future<void> _onAddEmployees() async {
    final added = await AddMembersSheet.show(
      context,
      location: _location,
      title: 'Assign Location',
      openSetupOnAdd: false,
    );
    if (added == true) {
      await _load();
      await _refreshList();
    }
  }

  Future<void> _onCheckInOut() async {
    final updated = await CheckInOutTimingSheet.show(
      context,
      locationId: _location.id,
      schedule: _schedule,
    );
    _applySchedule(updated);
  }

  Future<void> _onWorkingDays() async {
    final updated = await WorkingDaysSheet.show(
      context,
      locationId: _location.id,
      schedule: _schedule,
    );
    _applySchedule(updated);
  }

  Future<void> _onBreakTiming() async {
    final updated = await BreakTimingSheet.show(
      context,
      locationId: _location.id,
      schedule: _schedule,
    );
    _applySchedule(updated);
  }

  List<ManagerEmployeeModel> _membersAssignedToLocation(
    ManagerEmployeesProvider employees,
  ) {
    final locationKey = _location.id.trim().toLowerCase();
    final remembered = bindings.managerLocationsService.assignedMemberIds(
      _location.id,
    );

    bool matches(ManagerEmployeeModel member) {
      if (remembered.isNotEmpty) {
        final ids = <String>{
          member.id.trim(),
          if (member.userId != null) '${member.userId}',
        };
        for (final raw in remembered) {
          final id = raw.trim();
          if (id.isEmpty) continue;
          for (final candidate in ids) {
            if (candidate.toLowerCase() == id.toLowerCase()) return true;
          }
        }
      }
      if (member.locationId?.trim().toLowerCase() == locationKey) return true;
      for (final id in member.locationIds) {
        if (id.trim().toLowerCase() == locationKey) return true;
      }
      return false;
    }

    return [
      for (final member in employees.members)
        if (matches(member)) member,
    ];
  }

  Future<List<ManagerEmployeeModel>> _membersForReassign() async {
    final employeesProvider = context.read<ManagerEmployeesProvider>();
    final membersResult = await bindings.managerLocationsService
        .loadLocationMembers(locationId: _location.id);
    final fromApi = membersResult.data ?? const <ManagerEmployeeModel>[];

    // Members API can return empty (still HTTP OK) once is_active flips, or
    // briefly after assign — always merge directory + remembered ids so we
    // do not miss assignees when clearing this office.
    if (employeesProvider.members.isEmpty) {
      await employeesProvider.load();
      if (!mounted) return fromApi;
    }
    final fromDirectory = _membersAssignedToLocation(employeesProvider);
    if (fromDirectory.isEmpty) return fromApi;

    final byId = <String, ManagerEmployeeModel>{
      for (final member in fromApi) member.id.trim().toLowerCase(): member,
    };
    for (final member in fromDirectory) {
      byId.putIfAbsent(member.id.trim().toLowerCase(), () => member);
    }
    return byId.values.toList(growable: false);
  }

  Future<void> _reassignMembersAwayFromLocation({
    List<ManagerEmployeeModel>? knownMembers,
  }) async {
    final employeesProvider = context.read<ManagerEmployeesProvider>();
    var members = knownMembers ?? await _membersForReassign();
    if (!mounted) return;
    if (members.isEmpty) {
      members = await _membersForReassign();
      if (!mounted) return;
    }
    debugPrint(
      '[LocationStatus] reassign.members '
      'locationId=${_location.id} count=${members.length}',
    );
    if (members.isEmpty) {
      bindings.managerLocationsService.clearAssignedMembers(_location.id);
      return;
    }

    final removedId = _location.id;

    for (final member in members) {
      final userId = member.userId;
      if (userId == null) continue;

      var assignedIds = <String>{
        ...member.locationIds,
        if (member.locationId != null && member.locationId!.trim().isNotEmpty)
          member.locationId!,
        removedId,
      };
      var defaultId = member.locationId ?? '';

      final profile = await bindings.managerEmployeesService.loadEmployeeProfile(
        userId: userId,
      );
      if (profile.success && profile.data != null) {
        final data = profile.data!;
        assignedIds = {
          ...data.locationIds,
          if (data.locationId != null && data.locationId!.trim().isNotEmpty)
            data.locationId!,
          removedId,
        };
        defaultId = data.locationId ?? defaultId;
      }

      final payload = EmployeeLocationSavePayload.afterRemovingLocation(
        assignedIds: assignedIds,
        removedLocationId: removedId,
        currentDefaultId: defaultId,
      );

      // Always write — including empty remaining locations — so the deactivated
      // office is removed from the employee assignment that /auth/me serves.
      final result = await bindings.managerEmployeesService
          .updateEmployeeLocations(
            userId: userId,
            defaultLocationId: payload.defaultLocationId,
            locationIds: payload.locationIds,
          );
      debugPrint(
        '[LocationStatus] reassign.user userId=$userId '
        'success=${result.success} default=${payload.defaultLocationId} '
        'locations=${payload.locationIds.join(",")}',
      );
      if (!result.success) continue;

      employeesProvider.applyEmployeeLocations(
        userId: userId,
        defaultLocationId: payload.defaultLocationId,
        locationIds: payload.locationIds,
      );
    }

    bindings.managerLocationsService.clearAssignedMembers(_location.id);
  }

  Future<void> _onDeactivate() async {
    final confirmed = await DeleteLocationDialog.showSimple(context);
    if (!mounted || confirmed != true) return;

    debugPrint(
      '[LocationStatus] deactivate.start id=${_location.id} '
      'name=${_location.name}',
    );
    setState(() => _busy = true);

    // Capture + unassign while the location is still active — members lookup
    // and employee location writes often fail once is_active=false.
    final membersToUnassign = await _membersForReassign();
    if (!mounted) return;
    await _reassignMembersAwayFromLocation(knownMembers: membersToUnassign);
    if (!mounted) return;

    final result = await bindings.managerLocationsService.deactivateLocation(
      locationId: _location.id,
    );
    if (!mounted) return;

    debugPrint(
      '[LocationStatus] deactivate.api '
      'success=${result.isHttpOk} status=${result.statusCode} '
      'message=${result.message}',
    );

    if (!result.isHttpOk) {
      setState(() => _busy = false);
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to deactivate location.',
      );
      return;
    }

    context.read<ManagerLocationsProvider>().setLocationActive(
      locationId: _location.id,
      isActive: false,
    );

    setState(() {
      _location = _location.copyWith(isActive: false);
      _busy = false;
    });
    ToastHelper.locationDeactivated(context);
    await _refreshList();
    if (!mounted) return;
    _syncActiveFromProvider();
    setState(() {});
    debugPrint(
      '[LocationStatus] deactivate.done id=${_location.id} '
      'isActive=${_location.isActive}',
    );
  }

  Future<void> _onActivate() async {
    debugPrint(
      '[LocationStatus] activate.start id=${_location.id} '
      'name=${_location.name}',
    );
    setState(() => _busy = true);
    final result = await bindings.managerLocationsService.activateLocation(
      locationId: _location.id,
    );
    if (!mounted) return;

    debugPrint(
      '[LocationStatus] activate.api '
      'success=${result.isHttpOk} status=${result.statusCode} '
      'message=${result.message}',
    );

    if (!result.isHttpOk) {
      setState(() => _busy = false);
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to activate location.',
      );
      return;
    }

    context.read<ManagerLocationsProvider>().setLocationActive(
      locationId: _location.id,
      isActive: true,
    );

    setState(() {
      _location = _location.copyWith(isActive: true);
      _busy = false;
    });
    ToastHelper.locationActivated(context);
    await _refreshList();
    if (!mounted) return;
    _syncActiveFromProvider();
    setState(() {});
    debugPrint(
      '[LocationStatus] activate.done id=${_location.id} '
      'isActive=${_location.isActive}',
    );
  }

  Future<void> _onDelete() async {
    final action = await DeleteLocationDialog.showDetailed(context);
    if (!mounted) return;
    if (action != DeleteLocationAction.delete &&
        action != DeleteLocationAction.deactivate) {
      return;
    }

    setState(() => _busy = true);
    final result = await bindings.managerLocationsService.deleteLocation(
      locationId: _location.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to delete location.',
      );
      return;
    }

    ToastHelper.locationDeleted(context);
    await _refreshList();
    if (!mounted) return;
    _goToAllLocations();
  }

  void _goToAllLocations() {
    final navigator = Navigator.of(context);
    var foundAllLocations = false;
    navigator.popUntil((route) {
      if (route.settings.name == AllLocationsScreen.routeName) {
        foundAllLocations = true;
        return true;
      }
      return route.isFirst;
    });
    if (foundAllLocations || !mounted) return;
    navigator.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: AllLocationsScreen.routeName),
        builder: (_) => const AllLocationsScreen(),
      ),
    );
  }

  String get _subtitle {
    if (_location.allowCheckinAnywhere) {
      return 'Check in / Check out from any where';
    }
    return 'Check in / Check out from this location';
  }

  @override
  Widget build(BuildContext context) {
    final providerLocation =
        context.watch<ManagerLocationsProvider>().byId(_location.id);
    if (providerLocation != null) {
      _location = _location.copyWith(isActive: providerLocation.isActive);
    }
    final isActive = _location.isActive;

    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
        child: Column(
          children: [
            if (!isActive) const LocationDeactivatedBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    BackButtonBg(),
                    AppText.h3(_location.name),
                    const SizedBox(height: 10),
                    AppText.p1(_subtitle, color: kGreyColor),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ShimmerRefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Center(
                                  child: SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: ShimmerProgress(strokeWidth: 2.4),
                                  ),
                                ),
                              )
                            else if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: AppText.caption(
                                  _error!,
                                  color: kGreyColor,
                                  align: TextAlign.left,
                                ),
                              ),
                            _SettingsCard(
                              children: [
                                _SettingsTile(
                                  icon: Assets.imagesAddEmployee,
                                  label: 'Add to location',
                                  onTap: _busy ? () {} : _onAddEmployees,
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppText.h6(
                                'Settings',
                                weight: FontWeight.w700,
                                align: TextAlign.left,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _SettingsCard(
                              children: [
                                _SettingsTile(
                                  icon: Assets.GpsPin,
                                  label: 'Set up Location',
                                  subtitle: _location.address,
                                  onTap: _busy ? () {} : _onSetupLocation,
                                ),
                                const Divider(height: 1, color: kDividerColor),
                                _SettingsTile(
                                  icon: Assets.ClockIcon,
                                  label: 'Check In / Out Timing',
                                  onTap: _busy ? () {} : _onCheckInOut,
                                ),
                                const Divider(height: 1, color: kDividerColor),
                                _SettingsTile(
                                  icon: Assets.WorkingDays,
                                  label: 'Working Days',
                                  onTap: _busy ? () {} : _onWorkingDays,
                                ),
                                const Divider(height: 1, color: kDividerColor),
                                _SettingsTile(
                                  icon: Assets.BreakIcon,
                                  label: 'Break Timing',
                                  onTap: _busy ? () {} : _onBreakTiming,
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: kBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText.h4(
                                    'Delete Location',
                                    align: TextAlign.left,
                                  ),
                                  const SizedBox(height: 8),
                                  AppText.caption(
                                    isActive
                                        ? 'As soon as the location is deactivated, all users will lose access to this location.'
                                        : 'Activate this location to restore access for assigned users.',
                                    color: kGreyColor,
                                    weight: FontWeight.w400,
                                    align: TextAlign.left,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: MyButton(
                                          size: MyButtonSize.normal,
                                          height: 40,
                                          width: double.infinity,
                                          buttonText: isActive
                                              ? 'Deactivate location'
                                              : 'Activate location',
                                          backgroundColor: isActive
                                              ? kredColor
                                              : kPrimaryColor,
                                          isactive: !_busy,
                                          onTap: isActive
                                              ? _onDeactivate
                                              : _onActivate,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: MyButton(
                                          size: MyButtonSize.normal,
                                          height: 40,
                                          width: double.infinity,
                                          buttonText: 'Delete location',
                                          backgroundColor: kWhite,
                                          fontColor: kredColor,
                                          outlineColor: kredColor,
                                          isactive: !_busy,
                                          onTap: _onDelete,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            AppText.p2(
                              _location.createdBy.isEmpty
                                  ? 'Created by'
                                  : 'Created by ${_location.createdBy}',
                              color: kGreyColor,
                              align: TextAlign.left,
                            ),
                            const SizedBox(height: 4),
                            AppText.p2(
                              _location.createdAt.isEmpty
                                  ? 'Created at'
                                  : 'Created at ${_location.createdAt}',
                              color: kGreyColor,
                              align: TextAlign.left,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final String icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            CommonImageView(imagePath: icon, height: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.p2(
                    label,
                    color: kBlack,
                    weight: FontWeight.w500,
                    align: TextAlign.left,
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText.caption(
                      subtitle!,
                      color: kGreyColor,
                      weight: FontWeight.w400,
                      align: TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: kGreyColor),
          ],
        ),
      ),
    );
  }
}
