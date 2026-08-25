import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

enum ManagerDeviceStatus { active, pending, blocked, rejected }

class ManagerLinkedDevice {
  ManagerLinkedDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.status,
    required this.detail,
    this.actionedBy,
    this.isCurrent = false,
  });

  final String id;
  final String name;
  final String platform; // ios | android | desktop
  ManagerDeviceStatus status;
  final String detail;
  String? actionedBy;
  final bool isCurrent;

  /// Never shown while pending.
  String? get actionedByLabel {
    if (status == ManagerDeviceStatus.pending) return null;
    final by = actionedBy?.trim();
    if (by == null || by.isEmpty) return null;
    switch (status) {
      case ManagerDeviceStatus.active:
        return 'Approved by: $by';
      case ManagerDeviceStatus.rejected:
        return 'Rejected by: $by';
      case ManagerDeviceStatus.blocked:
        return 'Blocked by: $by';
      case ManagerDeviceStatus.pending:
        return null;
    }
  }
}

class ManagerLinkedDevicesSheet {
  ManagerLinkedDevicesSheet._();

  static Future<void> show({
    required BuildContext context,
    required String employeeName,
    int? userId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManagerLinkedDevicesSheetBody(
        employeeName: employeeName,
        userId: userId,
      ),
    );
  }
}

class _ManagerLinkedDevicesSheetBody extends StatefulWidget {
  const _ManagerLinkedDevicesSheetBody({
    required this.employeeName,
    this.userId,
  });

  final String employeeName;
  final int? userId;

  @override
  State<_ManagerLinkedDevicesSheetBody> createState() =>
      _ManagerLinkedDevicesSheetBodyState();
}

class _ManagerLinkedDevicesSheetBodyState
    extends State<_ManagerLinkedDevicesSheetBody> {
  List<ManagerLinkedDevice> _devices = const [];
  bool _loading = true;
  String? _error;

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
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Missing employee.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await bindings.managerEmployeesService.loadEmployeeDevices(
      userId: userId,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Failed to load devices.';
      });
      return;
    }

    setState(() {
      _devices = (result.data ?? const []).map(_fromApi).toList();
      _loading = false;
    });
  }

  ManagerLinkedDevice _fromApi(DeviceModel device) {
    return ManagerLinkedDevice(
      id: device.id.isNotEmpty ? device.id : device.deviceId,
      name: device.displayName.isEmpty ? 'Device' : device.displayName,
      platform: (device.platform.isEmpty ? device.os : device.platform)
          .toLowerCase(),
      status: _statusFrom(device),
      detail: device.isPending && !device.isApproved
          ? _formatRequested(device.requestedAt)
          : _formatLastUsed(device.lastActive ?? device.requestedAt),
      actionedBy: device.actionedBy,
      isCurrent: device.isCurrent,
    );
  }

  ManagerDeviceStatus _statusFrom(DeviceModel device) {
    if (device.isRejected) return ManagerDeviceStatus.rejected;
    if (device.isBlocked) return ManagerDeviceStatus.blocked;
    if (device.isApproved) return ManagerDeviceStatus.active;
    return ManagerDeviceStatus.pending;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  String _formatLastUsed(DateTime? dt) {
    if (dt == null) return 'No recent activity';
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'Last used: Today at ${_formatTime(local)}';
    return 'Last used: ${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _formatRequested(DateTime? dt) {
    if (dt == null) return 'Requested: —';
    final local = dt.toLocal();
    return 'Requested: ${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _iconFor(ManagerLinkedDevice device) {
    final platform = device.platform.toLowerCase();
    if (platform.contains('ios') || platform.contains('iphone') || platform.contains('apple')) {
      return Assets.imagesApple;
    }
    if (platform.contains('android')) {
      return Assets.imagesAndroid;
    }
    return Assets.imagesDesktop;
  }

  Future<void> _review(
    ManagerLinkedDevice device,
    String action,
    void Function(BuildContext) toast,
  ) async {
    final userId = widget.userId;
    if (userId == null) return;
    final result = await bindings.managerEmployeesService.reviewEmployeeDevice(
      userId: userId,
      deviceId: device.id,
      action: action,
    );
    if (!mounted) return;
    if (!result.success) {
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to update device.',
      );
      return;
    }
    await _load();
    if (!mounted) return;
    toast(context);
  }

  void _approve(ManagerLinkedDevice device) {
    _review(device, 'approve', ToastHelper.deviceApproved);
  }

  void _reject(ManagerLinkedDevice device) {
    _review(device, 'reject', ToastHelper.deviceRejected);
  }

  void _block(ManagerLinkedDevice device) {
    _review(device, 'block', ToastHelper.deviceBlocked);
  }

  void _unblock(ManagerLinkedDevice device) {
    _review(device, 'unblock', ToastHelper.deviceUnblocked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  ButtonAnimations.press(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: const BoxDecoration(
                        color: kGreyContainerColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 16),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        AppText.h5('Linked Devices', weight: FontWeight.w700),
                        const SizedBox(height: 2),
                        AppText.caption(
                          widget.employeeName,
                          color: kGreyColor,
                          weight: FontWeight.w400,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: AppText.caption(
                'Attendance actions are allowed only from the devices listed below.',
                color: kGreyColor,
                weight: FontWeight.w400,
                align: TextAlign.left,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: AppText.p2(_error!, color: kGreyColor))
                  : _devices.isEmpty
                  ? Center(
                      child: AppText.p2(
                        'No linked devices yet',
                        color: kGreyColor,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _DeviceCard(
                          device: _devices[index],
                          iconPath: _iconFor(_devices[index]),
                          onApprove: () => _approve(_devices[index]),
                          onReject: () => _reject(_devices[index]),
                          onBlock: () => _block(_devices[index]),
                          onUnblock: () => _unblock(_devices[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.iconPath,
    required this.onApprove,
    required this.onReject,
    required this.onBlock,
    required this.onUnblock,
  });

  final ManagerLinkedDevice device;
  final String iconPath;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;

  Color get _badgeColor {
    switch (device.status) {
      case ManagerDeviceStatus.active:
        return kPrimaryColor;
      case ManagerDeviceStatus.pending:
        return kYellowColorLight;
      case ManagerDeviceStatus.blocked:
      case ManagerDeviceStatus.rejected:
        return kRed;
    }
  }

  Color get _badgeBg {
    switch (device.status) {
      case ManagerDeviceStatus.active:
        return kPrimaryColor.withOpacity(0.15);
      case ManagerDeviceStatus.pending:
        return kContainerYellowColor2;
      case ManagerDeviceStatus.blocked:
      case ManagerDeviceStatus.rejected:
        return kContainerRedColor2;
    }
  }

  String get _badgeLabel {
    switch (device.status) {
      case ManagerDeviceStatus.active:
        return 'Active';
      case ManagerDeviceStatus.pending:
        return 'Pending';
      case ManagerDeviceStatus.blocked:
        return 'Blocked';
      case ManagerDeviceStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionedBy = device.actionedByLabel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header: icon + name …… status badge
          Row(
            children: [
              CommonImageView(imagePath: iconPath, height: 20),
              const SizedBox(width: 10),
              Expanded(
                child: AppText.h6(
                  device.name,
                  align: TextAlign.left,
                  weight: FontWeight.w500,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText.p2(_badgeLabel, color: _badgeColor),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// Last used / Requested
          AppText.p2(device.detail, color: kGreyColor, align: TextAlign.left),

          /// Approved/Rejected/Blocked by — hidden while pending
          if (actionedBy != null) ...[
            const SizedBox(height: 4),
            AppText.p2(actionedBy, color: kGreyColor, align: TextAlign.left),
          ],

          if (device.isCurrent) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: kBlue2),
                const SizedBox(width: 5),
                AppText.caption(
                  'Current Device',
                  color: kBlue2,
                  align: TextAlign.left,
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          if (device.status == ManagerDeviceStatus.pending)
            Row(
              children: [
                MyButton(
                  size: MyButtonSize.normal,
                  compact: false,
                  radius: 25,
                  height: 40,
                  width: 120,
                  buttonText: 'Approve',
                  backgroundColor: kPrimaryColor,
                  fontColor: kWhite,
                  onTap: () async => onApprove(),
                ),
                const SizedBox(width: 10),
                MyButton(
                  size: MyButtonSize.normal,
                  compact: false,
                  height: 40,
                  radius: 25,
                  width: 120,
                  buttonText: 'Reject',
                  backgroundColor: kredColor,
                  fontColor: kWhite,
                  onTap: () async => onReject(),
                ),
              ],
            )
          else if (device.status == ManagerDeviceStatus.active)
            MyButton(
              size: MyButtonSize.normal,
              compact: true,
              radius: 25,
              height: 40,
              buttonText: 'Block Device',
              backgroundColor: kWhite,
              fontColor: kRed,
              outlineColor: kRed,
              onTap: () async => onBlock(),
            )
          else
            MyButton(
              size: MyButtonSize.normal,
              compact: true,
              height: 40,
              radius: 25,
              buttonText: 'Unblock Device',
              backgroundColor: kWhite,
              fontColor: kGreyColor,
              outlineColor: kBorderColor,
              onTap: () async => onUnblock(),
            ),
        ],
      ),
    );
  }
}
