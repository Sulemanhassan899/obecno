// ignore_for_file: non_constant_identifier_names

import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/employee_module/more/providers/device_provider.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';

class LinkedDevices extends StatefulWidget {
  const LinkedDevices({super.key});

  @override
  State<LinkedDevices> createState() => _LinkedDevicesState();
}

class _LinkedDevicesState extends State<LinkedDevices> {
  final Set<String> _deletingIds = {};

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DeviceProvider>().loadLinkedDevices();
    });
  }

  String _deviceIcon(DeviceModel device) {
    final blob =
        '${device.platform} ${device.os} ${device.manufacturer} ${device.name} ${device.model}'
            .toLowerCase();
    if (blob.contains('ios') ||
        blob.contains('iphone') ||
        blob.contains('ipad')) {
      return Assets.imagesApple;
    }
    if (blob.contains('android') ||
        blob.contains('samsung') ||
        DeviceDisplayName.looksLikeEmulator(device.name) ||
        DeviceDisplayName.looksLikeEmulator(device.model) ||
        device.displayName == 'Emulator' ||
        RegExp(r'^A\d{2}$').hasMatch(device.displayName)) {
      return Assets.imagesAndroid;
    }
    return Assets.imagesDesktop;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  String _formatStamp(DateTime dt, {required String prefix}) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) {
      return '$prefix: Today at ${_formatTime(local)}';
    }
    return '$prefix: ${_months[local.month - 1]} ${local.day}, ${local.year} at ${_formatTime(local)}';
  }

  (Color text, Color bg) _statusColors(String label) {
    switch (label) {
      case 'Active':
        return (kPrimaryColor, kPrimaryColor.withOpacity(0.15));
      case 'Pending':
        return (kYellowColorLight, kContainerYellowColor2);
      case 'Blocked':
      case 'Rejected':
        return (kRed, kContainerRedColor2);
      default:
        return (kGreyColor, kGreyColor.withOpacity(0.1));
    }
  }

  Future<void> _onDeleteRequest(DeviceModel device) async {
    final key = _deleteKey(device);
    if (key.isEmpty || _deletingIds.contains(key)) return;

    setState(() => _deletingIds.add(key));

    final provider = context.read<DeviceProvider>();
    final ok = await provider.deleteDevice(device);

    if (!mounted) return;
    setState(() => _deletingIds.remove(key));

    if (ok) {
      ToastHelper.deviceDeleted(context);
    } else {
      ToastHelper.deviceDeleteFailed(context, message: provider.errorMessage);
    }
  }

  String _deleteKey(DeviceModel device) {
    if (device.id.isNotEmpty && device.id != '0') return device.id;
    return device.deviceId;
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.read<DeviceProvider>();

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.HORIZONTAL,
        child: ListenableBuilder(
          listenable: deviceProvider,
          builder: (context, _) {
            final devices = deviceProvider.devices;
            final isInitialLoad = deviceProvider.isLoading && devices.isEmpty;
            final showError =
                !isInitialLoad && devices.isEmpty && deviceProvider.hasError;
            final showEmpty = !isInitialLoad && !showError && devices.isEmpty;

            return RefreshIndicator(
              onRefresh: () => deviceProvider.loadLinkedDevices(),
              child: ListView(
                children: [
                  const SizedBox(height: 20),
                  BackButtonBg(title: "Linked Devices"),
                  const SizedBox(height: 20),
                  AppText.p1(
                    "Attendance actions are allowed only from the devices listed below.",
                    align: TextAlign.left,
                    color: kGreyColor,
                  ),
                  const SizedBox(height: 20),
                  if (isInitialLoad)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: kPrimaryColor),
                      ),
                    )
                  else if (showError)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          children: [
                            AppText.h6(
                              deviceProvider.errorMessage ??
                                  "Failed to load devices",
                              align: TextAlign.center,
                              color: kGreyColor,
                            ),
                            const SizedBox(height: 16),
                            MyButton(
                              size: MyButtonSize.normal,
                              width: 140,
                              buttonText: "Retry",
                              onTap: () => deviceProvider.loadLinkedDevices(),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (showEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: AppText.h6(
                          "No linked devices yet",
                          align: TextAlign.center,
                          color: kGreyColor,
                        ),
                      ),
                    )
                  else
                    ..._buildDeviceList(deviceProvider),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildDeviceList(DeviceProvider deviceProvider) {
    return DeviceModel.currentFirst(deviceProvider.devices)
        .expand((device) => [_deviceCard(device), const SizedBox(height: 12)])
        .toList(growable: false);
  }

  String? _nameForUserId(String? id) {
    if (id == null || id.isEmpty) return null;
    final user = bindings.authProvider.user;
    if (user != null && user.id == id && user.name.trim().isNotEmpty) {
      return user.name.trim();
    }
    for (final member in bindings.managerEmployeesProvider.members) {
      if (member.id.toString() == id && member.name.trim().isNotEmpty) {
        return member.name.trim();
      }
    }
    return null;
  }

  String? _actionedByLabel(DeviceModel device) {
    final existing = device.actionedByLabel;
    if (existing != null) return existing;
    if (device.isPending) return null;
    final name = _nameForUserId(device.actionedById);
    if (name == null || name.isEmpty) return null;
    if (device.isApproved) return 'Approved by: $name';
    if (device.isRejected) return 'Rejected by: $name';
    if (device.isBlocked) return 'Blocked by: $name';
    return null;
  }

  Widget _deviceCard(DeviceModel device) {
    final status = device.statusLabel;
    final colors = _statusColors(status);
    final isDeleting = _deletingIds.contains(_deleteKey(device));
    final actionedBy = _actionedByLabel(device);
    final detailLine = device.isPending
        ? _formatStamp(device.cardTimestamp, prefix: 'Requested')
        : _formatStamp(device.cardTimestamp, prefix: 'Last used');

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
          Row(
            children: [
              CommonImageView(imagePath: _deviceIcon(device), height: 20),
              const SizedBox(width: 10),
              Expanded(
                child: AppText.h6(
                  device.displayName,
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
                  color: colors.$2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText.p2(status, color: colors.$1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppText.p2(detailLine, align: TextAlign.left, color: kGreyColor),
          if (actionedBy != null) ...[
            const SizedBox(height: 4),
            AppText.p2(actionedBy, align: TextAlign.left, color: kGreyColor),
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
          if (device.showDeleteRequest) ...[
            const SizedBox(height: 16),
            MyButton(
              size: MyButtonSize.normal,
              compact: true,
              buttonText: isDeleting ? 'Deleting' : 'Delete Request',
              backgroundColor: kWhite,
              fontColor: kRed,
              outlineColor: kRed,
              radius: 25,
              showLoadingSpinner: false,
              isLoadingExternally: isDeleting,
              onTap: isDeleting
                  ? null
                  : () async {
                      await _onDeleteRequest(device);
                    },
            ),
          ],
        ],
      ),
    );
  }
}
