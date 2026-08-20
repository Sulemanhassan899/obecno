// ignore_for_file: non_constant_identifier_names

import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/employee_module/more/providers/device_provider.dart';
import 'package:obecno/core/generated/assets.dart';
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
      context.read<DeviceProvider>().fetchDevices();
    });
  }

  String _deviceIcon(DeviceModel device) {
    final platform = device.platform.toLowerCase();
    final os = device.os.toLowerCase();
    if (platform.contains('ios') || os.contains('ios')) {
      return Assets.imagesApple;
    }
    if (platform.contains('android') || os.contains('android')) {
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

  String _formatLastUsed(DateTime? dt) {
    if (dt == null) return 'No recent activity';
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) {
      return 'Last used: Today at ${_formatTime(local)}';
    }
    return 'Last used: ${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _formatRequested(DateTime? dt) {
    if (dt == null) return 'Requested: —';
    final local = dt.toLocal();
    return 'Requested: ${_months[local.month - 1]} ${local.day}, ${local.year}';
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
    if (device.id.isEmpty || _deletingIds.contains(device.id)) return;

    setState(() => _deletingIds.add(device.id));

    final provider = context.read<DeviceProvider>();
    final ok = await provider.deleteDevice(device.id);

    if (!mounted) return;
    setState(() => _deletingIds.remove(device.id));

    if (ok) {
      ToastHelper.deviceDeleted(context);
    } else {
      ToastHelper.deviceDeleteFailed(context, message: provider.errorMessage);
    }
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
              onRefresh: () => deviceProvider.refreshDevices(),
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
                              onTap: () => deviceProvider.fetchDevices(),
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
    final devices = deviceProvider.devices;
    final currentDevice = deviceProvider.currentDevice;
    final otherDevices = currentDevice == null
        ? devices
        : devices
              .where((device) => device.deviceId != currentDevice.deviceId)
              .toList(growable: false);

    final widgets = <Widget>[];

    if (currentDevice != null) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(_deviceCard(currentDevice));
      widgets.add(const SizedBox(height: 12));
    }

    widgets.addAll(
      otherDevices.expand(
        (device) => [_deviceCard(device), const SizedBox(height: 12)],
      ),
    );

    return widgets;
  }

  Widget _deviceCard(DeviceModel device) {
    final status = device.statusLabel;
    final colors = _statusColors(status);
    final isDeleting = _deletingIds.contains(device.id);
    final actionedBy = device.actionedByLabel;
    final detailLine = device.isPending
        ? _formatRequested(device.requestedAt ?? device.lastActive)
        : _formatLastUsed(device.lastActive);

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
          const SizedBox(height: 16),
          MyButton(
            size: MyButtonSize.normal,
            compact: true,
            buttonText: isDeleting ? 'Deleting...' : 'Delete Request',
            backgroundColor: kWhite,
            fontColor: kRed,
            outlineColor: kRed,
            radius: 25,
            onTap: isDeleting
                ? () async {}
                : () async {
                    await _onDeleteRequest(device);
                  },
          ),
        ],
      ),
    );
  }
}
