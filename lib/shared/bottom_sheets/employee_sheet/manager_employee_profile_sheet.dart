import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/edit_sheets/break_timing_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/edit_sheets/check_in_out_timing_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/employee_sheet/account_information_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/employee_sheet/employee_default_locations_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/employee_sheet/manager_employee_attendance_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/employee_sheet/manager_linked_devices_sheet.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class ManagerEmployeeProfileSheet {
  ManagerEmployeeProfileSheet._();

  static Future<void> show({
    required BuildContext context,
    required ManagerAttendanceDetailsData data,
    VoidCallback? onAttendanceTap,
    VoidCallback? onLocationsTap,
    VoidCallback? onSettingsTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ManagerEmployeeProfileSheetBody(
        data: data,
        onAttendanceTap:
            onAttendanceTap ??
            () {
              ManagerEmployeeAttendanceSheet.show(
                context: sheetContext,
                employeeName: data.name,
              );
            },
        onLocationsTap:
            onLocationsTap ??
            () {
              EmployeeDefaultLocationsSheet.show(
                context: sheetContext,
                employeeName: data.name,
              );
            },
        onSettingsTap:
            onSettingsTap ??
            () {
              AccountInformationSheet.show(
                context: sheetContext,
                employeeName: data.name,
              );
            },
      ),
    );
  }
}

class _ManagerEmployeeProfileSheetBody extends StatelessWidget {
  const _ManagerEmployeeProfileSheetBody({
    required this.data,
    this.onAttendanceTap,
    this.onLocationsTap,
    this.onSettingsTap,
  });

  final ManagerAttendanceDetailsData data;
  final VoidCallback? onAttendanceTap;
  final VoidCallback? onLocationsTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _roundIconButton(
                      icon: Icons.close,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    _roundIconButton(
                      asset: Assets.imagesSetting,
                      onTap: () => onSettingsTap?.call(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          ClipOval(
                            child: CommonImageView(
                              imagePath: data.photo ?? Assets.imagesUserimage,
                              height: 96,
                              width: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: ButtonAnimations.press(
                              onTap: () {},
                              child: CommonImageView(
                                imagePath: Assets.imagesProfileEditPen,
                                height: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppText.h5(
                      data.name,
                      weight: FontWeight.w700,
                      color: kBlack,
                    ),
                    if (data.role != null && data.role!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      AppText.p2(
                        data.role!,
                        color: kGreyColor,
                        weight: FontWeight.w400,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _contactButton(Assets.CallMP),
                        const SizedBox(width: 12),
                        _contactButton(Assets.MsgMP),
                        const SizedBox(width: 12),
                        _contactButton(Assets.WhatsappMP),
                        const SizedBox(width: 12),
                        _contactButton(Assets.EmailMP),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _actionCard(
                            iconAsset: Assets.imagesCalender,
                            label: "Attendance",
                            onTap: onAttendanceTap,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionCard(
                            iconAsset: Assets.imagesAddLocationIcon,
                            label: "Locations",
                            onTap: onLocationsTap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    AppText.h5("Settings", align: TextAlign.left),
                    const SizedBox(height: 12),
                    _settingsGroup(
                      children: [
                        _settingsTile(
                          iconAsset: Assets.imagesLinkDevices,
                          title: "Linked Devices",
                          onTap: () {
                            ManagerLinkedDevicesSheet.show(
                              context: context,
                              employeeName: data.name,
                            );
                          },
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _settingsTile(
                          iconAsset: Assets.imagesKey,
                          title: "Reset password",
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _settingsGroup(
                      children: [
                        _settingsTile(
                          iconAsset: Assets.imagesOfficeLocationIcon,
                          title: "Default Offices & Locations",
                          onTap: () {
                            EmployeeDefaultLocationsSheet.show(
                              context: context,
                              employeeName: data.name,
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: kbackground2,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: AppText.caption(
                              "Attendance rules are set by the [ location name ]",
                              color: kGreyColor,
                              align: TextAlign.left,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _settingsTile(
                          iconAsset: Assets.ClockIcon,
                          title: "Check In / Out Timing",
                          onTap: () => CheckInOutTimingSheet.show(context),
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _settingsTile(
                          iconAsset: Assets.BreakIcon,
                          title: "Break Timing",
                          onTap: () => BreakTimingSheet.show(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _settingsGroup(
                      children: [
                        _settingsTile(
                          iconAsset: Assets.DeactiviateUserIcon,
                          title: "Deactivate Account",
                          titleColor: kredColor,
                          showChevron: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AppText.p2(
                      "Created by [Name]",
                      color: kGreyColor,
                      align: TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    AppText.p2(
                      "Created at 20 Jan 2026",
                      color: kGreyColor,
                      align: TextAlign.left,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roundIconButton({
    IconData? icon,
    String? asset,
    required VoidCallback onTap,
  }) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: kbackground2, shape: BoxShape.circle),
        child: asset != null
            ? CommonImageView(imagePath: asset, height: 18)
            : Icon(icon, size: 20, color: kBlack200),
      ),
    );
  }

  Widget _contactButton(String asset) {
    return ButtonAnimations.press(
      onTap: () {},
      child: CommonImageView(
        imagePath: asset,
        height: 50,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _actionCard({
    required String iconAsset,
    required String label,
    VoidCallback? onTap,
  }) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          children: [
            CommonImageView(imagePath: iconAsset, height: 22),
            const SizedBox(height: 10),
            AppText.p2(label, color: kSubText, weight: FontWeight.w500),
          ],
        ),
      ),
    );
  }

  Widget _settingsGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    String? iconAsset,
    IconData? icon,
    required String title,
    Color? titleColor,
    Color? iconColor,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          if (iconAsset != null)
            CommonImageView(imagePath: iconAsset, height: 20)
          else
            Icon(icon, size: 20, color: iconColor ?? kBlack200),
          const SizedBox(width: 12),
          Expanded(
            child: AppText.p2(
              title,
              color: titleColor ?? kBlack,
              weight: FontWeight.w500,
              align: TextAlign.left,
            ),
          ),
          if (showChevron)
            Icon(Icons.chevron_right, color: kGreyColor.withOpacity(0.8)),
        ],
      ),
    );

    if (onTap == null) return row;
    return ButtonAnimations.press(onTap: onTap, child: row);
  }
}
