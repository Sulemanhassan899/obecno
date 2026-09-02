import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
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
    _load();
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
    }

    final schedule = await bindings.managerLocationsService
        .loadLocationSchedule(locationId: _location.id);
    if (!mounted) return;
    setState(() {
      if (schedule.success && schedule.data != null) {
        _schedule = schedule.data!;
        _location = _location.copyWith(schedule: schedule.data);
      }
      _loading = false;
    });
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
    final selected = await SetupLocationMapScreen.open(
      context,
      initialAddress: _location.address,
      initialLatitude: _location.latitude,
      initialLongitude: _location.longitude,
    );
    if (!mounted || selected == null) return;

    setState(() => _busy = true);
    final next = _location.copyWith(
      address: selected.address,
      latitude: selected.latitude,
      longitude: selected.longitude,
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

  Future<void> _onDeactivate() async {
    final confirmed = await DeleteLocationDialog.showSimple(context);
    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    final result = await bindings.managerLocationsService.deactivateLocation(
      locationId: _location.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to deactivate location.',
      );
      return;
    }

    ToastHelper.locationDeactivated(context);
    await _refreshList();
    if (!mounted) return;
    Navigator.pop(context);
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
    Navigator.pop(context);
  }

  String get _subtitle {
    if (_location.allowCheckinAnywhere) {
      return 'Check in / Check out from any where';
    }
    return 'Check in / Check out from this location';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
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
                child: RefreshIndicator(
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
                              child: CircularProgressIndicator(strokeWidth: 2.4),
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
                              'As soon as the location is deactivated, all users will lose access to this location.',
                              color: kGreyColor,
                              weight: FontWeight.w400,
                              align: TextAlign.left,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: MyButton(
                                    size: MyButtonSize.normal,
                                    height: 40,
                                    buttonText: 'Deactivated location',
                                    backgroundColor: kredColor,
                                    isactive: !_busy,
                                    onTap: _onDeactivate,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: MyButton(
                                    size: MyButtonSize.normal,
                                    height: 40,
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
