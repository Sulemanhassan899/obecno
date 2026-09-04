import 'dart:io';

import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/features/auth/data/models/communication_options.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/break_timing_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/check_in_out_timing_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/working_days_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/account_information_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/deactivate_account_dialog.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/employee_default_locations_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_attendance_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_linked_devices_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
      builder: (_) => _ManagerEmployeeProfileSheetBody(
        data: data,
        onAttendanceTap: onAttendanceTap,
        onLocationsTap: onLocationsTap,
        onSettingsTap: onSettingsTap,
      ),
    );
  }
}

class _ManagerEmployeeProfileSheetBody extends StatefulWidget {
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
  State<_ManagerEmployeeProfileSheetBody> createState() =>
      _ManagerEmployeeProfileSheetBodyState();
}

class _ManagerEmployeeProfileSheetBodyState
    extends State<_ManagerEmployeeProfileSheetBody> {
  late ManagerAttendanceDetailsData _data;
  bool _uploadingPhoto = false;
  File? _localPhoto;
  int _locationsRevision = 0;
  bool _updatingStatus = false;

  bool get _canEditPhoto =>
      bindings.authProvider.homeTarget == AuthHomeTarget.manager;

  ManagerEmployeeModel? _memberFor(int? userId) {
    if (userId == null) return null;
    for (final member in bindings.managerEmployeesProvider.members) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  DateTime? _joiningDateFor(int? userId) => _memberFor(userId)?.joiningDate;

  ManagerEmployeeStatus _statusFor(int? userId) =>
      _memberFor(userId)?.status ?? ManagerEmployeeStatus.active;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  Future<ImageSource?> _pickPhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText.h5(
                          'Update photo',
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close, size: 22),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: AppText.p1(
                    'Choose from gallery',
                    align: TextAlign.left,
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: AppText.p1('Take a photo', align: TextAlign.left),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onEditPhoto() async {
    if (!_canEditPhoto || _uploadingPhoto) return;
    final userId = _data.userId;
    if (userId == null) {
      ToastHelper.error(context, message: 'Unable to update this photo.');
      return;
    }

    final source = await _pickPhotoSource();
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
    } catch (_) {
      if (!mounted) return;
      ToastHelper.error(context, message: 'Unable to open camera or gallery.');
      return;
    }
    if (picked == null || !mounted) return;
    final selected = picked;

    setState(() {
      _localPhoto = File(selected.path);
      _uploadingPhoto = true;
    });

    final bytes = await selected.readAsBytes();
    final result = await bindings.managerEmployeesService.updateEmployeePhoto(
      userId: userId,
      photoBytes: bytes,
      fileName: selected.name.isNotEmpty ? selected.name : 'photo.jpg',
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() => _uploadingPhoto = false);
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to update photo.',
      );
      return;
    }

    final photo = result.data?.photo?.trim();
    setState(() {
      _uploadingPhoto = false;
      if (photo != null && photo.isNotEmpty) {
        _data = _data.copyWith(photo: photo);
        _localPhoto = null;
      }
    });
    if (photo != null && photo.isNotEmpty) {
      bindings.managerEmployeesProvider.applyEmployeePhoto(
        userId: userId,
        photoUrl: photo,
      );
    }
    ToastHelper.changesSaved(context);
  }

  Future<void> _onToggleAccount() async {
    if (_updatingStatus) return;
    final userId = _data.userId;
    if (userId == null) {
      ToastHelper.error(context, message: 'Unable to update this account.');
      return;
    }

    final current = _statusFor(userId);
    if (current == ManagerEmployeeStatus.deleted) return;
    final activate = current == ManagerEmployeeStatus.disabled;
    final confirmed = await DeactivateAccountDialog.show(
      context,
      activate: activate,
      employeeName: _data.name,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingStatus = true);
    final nextStatus = activate
        ? ManagerEmployeeStatus.active
        : ManagerEmployeeStatus.disabled;
    final result = await bindings.managerEmployeesService.updateEmployeeStatus(
      userId: userId,
      status: nextStatus.apiValue,
    );
    if (!mounted) return;
    setState(() => _updatingStatus = false);

    if (!result.success) {
      ToastHelper.error(
        context,
        message:
            result.message ??
            (activate
                ? 'Failed to activate account.'
                : 'Failed to deactivate account.'),
      );
      return;
    }

    bindings.managerEmployeesProvider.applyEmployeeStatus(
      userId: userId,
      status: nextStatus,
    );

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      if (activate) {
        ToastHelper.accountActivated(rootContext);
      } else {
        ToastHelper.accountDeactivated(rootContext);
      }
    });
  }

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
                      onTap: () {
                        if (widget.onSettingsTap != null) {
                          widget.onSettingsTap!();
                          return;
                        }
                        AccountInformationSheet.show(
                          context: context,
                          employeeName: _data.name,
                          userId: _data.userId,
                        );
                      },
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
                              file: _localPhoto,
                              url: _localPhoto == null && _data.hasNetworkPhoto
                                  ? _data.photo
                                  : null,
                              imagePath:
                                  _localPhoto == null && !_data.hasNetworkPhoto
                                  ? _data.photoPath
                                  : null,
                              height: 96,
                              width: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (_uploadingPhoto)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Colors.black26,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kWhite,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_canEditPhoto)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: ButtonAnimations.press(
                                onTap: _onEditPhoto,
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
                      _data.name,
                      weight: FontWeight.w700,
                      color: kBlack,
                    ),
                    if (_data.role != null &&
                        _data.role!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      AppText.p2(
                        _data.role!,
                        color: kGreyColor,
                        weight: FontWeight.w400,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _contactButtons(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _actionCard(
                            iconAsset: Assets.imagesCalender,
                            label: "Attendance",
                            onTap: () {
                              if (widget.onAttendanceTap != null) {
                                widget.onAttendanceTap!();
                                return;
                              }
                              ManagerEmployeeAttendanceSheet.show(
                                context: context,
                                employeeName: _data.name,
                                userId: _data.userId,
                                role: _data.role,
                                photo: _data.photo,
                                joiningDate: _joiningDateFor(_data.userId),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionCard(
                            iconAsset: Assets.imagesAddLocationIcon,
                            label: "Locations",
                            onTap: () async {
                              if (widget.onLocationsTap != null) {
                                widget.onLocationsTap!();
                                return;
                              }
                              await EmployeeDefaultLocationsSheet.show(
                                context: context,
                                employeeName: _data.name,
                                userId: _data.userId,
                                mode: EmployeeLocationsSheetMode.assigned,
                              );
                              if (mounted) {
                                setState(() => _locationsRevision++);
                              }
                            },
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
                              employeeName: _data.name,
                              userId: _data.userId,
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
                          onTap: () async {
                            await EmployeeDefaultLocationsSheet.show(
                              context: context,
                              employeeName: _data.name,
                              userId: _data.userId,
                              mode: EmployeeLocationsSheetMode.defaultLocation,
                            );
                            if (mounted) {
                              setState(() => _locationsRevision++);
                            }
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
                            child: _AttendanceRulesBanner(
                              key: ValueKey(_locationsRevision),
                              userId: _data.userId,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _settingsTile(
                          iconAsset: Assets.ClockIcon,
                          title: "Check In / Out Timing",
                          onTap: () => CheckInOutTimingSheet.show(
                            context,
                            userId: _data.userId,
                            employeeName: _data.name,
                          ),
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _settingsTile(
                          iconAsset: Assets.WorkingDays,
                          title: "Working Days",
                          onTap: () => WorkingDaysSheet.show(
                            context,
                            userId: _data.userId,
                            employeeName: _data.name,
                          ),
                        ),
                        const Divider(height: 1, color: kDividerColor),
                        _settingsTile(
                          iconAsset: Assets.BreakIcon,
                          title: "Break Timing",
                          onTap: () => BreakTimingSheet.show(
                            context,
                            userId: _data.userId,
                            employeeName: _data.name,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _settingsGroup(
                      children: [
                        _settingsTile(
                          iconAsset: Assets.DeactiviateUserIcon,
                          title:
                              _statusFor(_data.userId) ==
                                  ManagerEmployeeStatus.disabled
                              ? 'Activate Account'
                              : 'Deactivate Account',
                          titleColor:
                              _statusFor(_data.userId) ==
                                  ManagerEmployeeStatus.disabled
                              ? kPrimaryColor
                              : kredColor,
                          showChevron: false,
                          onTap:
                              _statusFor(_data.userId) ==
                                      ManagerEmployeeStatus.deleted ||
                                  _updatingStatus
                              ? null
                              : _onToggleAccount,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ProfileCreatedFooter(userId: _data.userId),
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

  Widget _contactButtons() {
    final options =
        bindings.authProvider.user?.communicationOptions ??
        CommunicationOptions.all;
    final buttons = <Widget>[
      if (options.showCall) _contactButton(Assets.CallMP),
      if (options.showMessage) _contactButton(Assets.MsgMP),
      if (options.showWhatsapp) _contactButton(Assets.WhatsappMP),
      if (options.showEmail) _contactButton(Assets.EmailMP),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          buttons[i],
        ],
      ],
    );
  }

  Widget _contactButton(String asset) {
    return ButtonAnimations.press(
      onTap: () {},
      child: CommonImageView(imagePath: asset, height: 50, fit: BoxFit.contain),
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

class _AttendanceRulesBanner extends StatefulWidget {
  const _AttendanceRulesBanner({super.key, this.userId});

  final int? userId;

  @override
  State<_AttendanceRulesBanner> createState() => _AttendanceRulesBannerState();
}

class _AttendanceRulesBannerState extends State<_AttendanceRulesBanner> {
  String _locationName = 'location';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = widget.userId;
    if (userId == null) return;
    final profile = await bindings.managerEmployeesService.loadEmployeeProfile(
      userId: userId,
    );
    if (!mounted) return;
    var name = profile.data?.locationName?.trim();
    if (name == null || name.isEmpty) {
      final permissions = await bindings.managerEmployeesService
          .loadEmployeePermissions(userId: userId);
      if (!mounted) return;
      name = ManagerEmployeePolicy.fromItems(
        permissions.data ?? const [],
      ).locationName;
    }
    if (name != null && name.trim().isNotEmpty) {
      final resolved = name.trim();
      setState(() => _locationName = resolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppText.caption(
      'Attendance rules are set by the $_locationName',
      color: kGreyColor,
      align: TextAlign.left,
    );
  }
}

class _ProfileCreatedFooter extends StatefulWidget {
  const _ProfileCreatedFooter({this.userId});

  final int? userId;

  @override
  State<_ProfileCreatedFooter> createState() => _ProfileCreatedFooterState();
}

class _ProfileCreatedFooterState extends State<_ProfileCreatedFooter> {
  String? _createdBy;
  String? _createdAt;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = widget.userId;
    if (userId == null) return;
    final result = await bindings.managerEmployeesService.loadEmployeeProfile(
      userId: userId,
    );
    if (!mounted || result.data == null) return;
    setState(() {
      _createdBy = result.data!.createdBy;
      _createdAt = _formatDate(result.data!.createdAt);
    });
  }

  String? _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day} ${_months[parsed.month - 1]} ${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_createdBy == null && _createdAt == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_createdBy != null && _createdBy!.isNotEmpty)
          AppText.p2(
            'Created by $_createdBy',
            color: kGreyColor,
            align: TextAlign.left,
          ),
        if (_createdAt != null && _createdAt!.isNotEmpty) ...[
          const SizedBox(height: 4),
          AppText.p2(
            'Created at $_createdAt',
            color: kGreyColor,
            align: TextAlign.left,
          ),
        ],
      ],
    );
  }
}
