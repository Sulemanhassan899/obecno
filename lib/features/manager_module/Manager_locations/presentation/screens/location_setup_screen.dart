import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/core/helpers/toast_helper.dart';
import 'package:Obecno/demo/manager_location_model.dart';
import 'package:Obecno/features/manager_module/Manager_locations/presentation/screens/setup_location_map_screen.dart';
import 'package:Obecno/shared/bottom_sheets/edit_sheets/break_timing_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/edit_sheets/check_in_out_timing_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/employee_sheet/add_members_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/location_sheet/delete_location_dialog.dart';
import 'package:Obecno/shared/bottom_sheets/edit_sheets/working_days_sheet.dart';
import 'package:Obecno/widgets/back_button.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key, required this.location});

  final ManagerLocationModel location;

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  late ManagerLocationModel _location;

  @override
  void initState() {
    super.initState();
    _location = widget.location;
  }

  Future<void> _onSetupLocation() async {
    final selected = await SetupLocationMapScreen.open(
      context,
      initialAddress: _location.address,
      initialLatitude: _location.latitude,
      initialLongitude: _location.longitude,
    );
    if (!mounted || selected == null) return;

    setState(() {
      _location = _location.copyWith(
        address: selected.address,
        latitude: selected.latitude,
        longitude: selected.longitude,
      );
    });

    ToastHelper.changesSaved(context);
  }

  Future<void> _onDeactivate() async {
    final action = await DeleteLocationDialog.showDetailed(context);
    if (!mounted) return;
    if (action == DeleteLocationAction.deactivate ||
        action == DeleteLocationAction.delete) {
      if (action == DeleteLocationAction.deactivate) {
        ToastHelper.locationDeactivated(context);
      } else {
        ToastHelper.locationDeleted(context);
      }
      if (action == DeleteLocationAction.delete) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _onDelete() async {
    final confirmed = await DeleteLocationDialog.showSimple(context);
    if (!mounted) return;
    if (confirmed == true) {
      ToastHelper.locationDeleted(context);
      Navigator.pop(context);
    }
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
              AppText.p1(
                'Check in / Check out from any where',
                color: kGreyColor,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Assets.imagesAddEmployee,
                          label: 'Add to location',
                          onTap: () {
                            AddMembersSheet.show(
                              context,
                              location: _location,
                              title: 'Assign Location',
                              openSetupOnAdd: false,
                            );
                          },
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
                          onTap: _onSetupLocation,
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _SettingsTile(
                          icon: Assets.ClockIcon,
                          label: 'Check In / Out Timing',
                          onTap: () => CheckInOutTimingSheet.show(context),
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _SettingsTile(
                          icon: Assets.WorkingDays,
                          label: 'Working Days',
                          onTap: () => WorkingDaysSheet.show(context),
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _SettingsTile(
                          icon: Assets.BreakIcon,
                          label: 'Break Timing',
                          onTap: () => BreakTimingSheet.show(context),
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
                          AppText.h4('Delete Location', align: TextAlign.left),
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
                              MyButton(
                                size: MyButtonSize.normal,
                                width: 200,
                                height: 40,
                                buttonText: 'Deactivated location',
                                backgroundColor: kredColor,
                                onTap: () async => _onDelete(),
                              ),
                              const SizedBox(width: 10),
                              MyButton(
                                size: MyButtonSize.normal,
                                width: 130,
                                height: 40,
                                buttonText: 'Delete location',
                                backgroundColor: kWhite,
                                fontColor: kredColor,
                                outlineColor: kredColor,
                                onTap: () async => _onDeactivate(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppText.p2(
                      'Created by ${_location.createdBy}',
                      color: kGreyColor,
                      align: TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    AppText.p2(
                      'Created at ${_location.createdAt}',
                      color: kGreyColor,
                      align: TextAlign.left,
                    ),
                    const SizedBox(height: 20),
                  ],
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
