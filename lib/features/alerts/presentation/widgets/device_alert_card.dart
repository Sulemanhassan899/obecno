import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/alerts/data/models/device_alert_item.dart';
import 'package:obecno/features/more/data/models/device_model.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class DeviceAlertCard extends StatelessWidget {
  const DeviceAlertCard({
    super.key,
    required this.item,
    required this.isManagerView,
    this.busy = false,
    this.onDelete,
    this.onApprove,
    this.onReject,
  });

  final DeviceAlertItem item;
  final bool isManagerView;
  final bool busy;
  final VoidCallback? onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

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
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'pm' : 'am';
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final device = item.device;
    final subtitle = item.emailLabel.isNotEmpty
        ? item.emailLabel
        : device.displayName;
    final place = item.placeLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CommonImageView(
                  imagePath: _deviceIcon(device),
                  height: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.h6(
                      item.title(isManagerView: isManagerView),
                      align: TextAlign.left,
                      weight: FontWeight.w600,
                    ),
                    if (isManagerView) ...[
                      const SizedBox(height: 4),
                      AppText.p2(subtitle, align: TextAlign.left),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppText.p2(
                            place,
                            align: TextAlign.left,
                            color: kGreyColor,
                          ),
                        ),
                        AppText.p2(
                          _formatTime(device.cardTimestamp),
                          color: kGreyColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (busy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (isManagerView && device.isPending)
                      Row(
                        children: [
                          Expanded(
                            child: MyButton(
                              size: MyButtonSize.normal,
                              compact: false,
                              radius: 30,
                              height: 32,
                              buttonText: 'Approve',
                              backgroundColor: kPrimaryColor,
                              fontColor: kWhite,
                              onTap: () async => onApprove?.call(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MyButton(
                              size: MyButtonSize.normal,
                              compact: false,
                              radius: 30,
                              height: 32,
                              buttonText: 'Reject',
                              backgroundColor: kredColor,
                              fontColor: kWhite,
                              onTap: () async => onReject?.call(),
                            ),
                          ),
                        ],
                      )
                    else if (!isManagerView && device.isPending)
                      MyButton(
                        size: MyButtonSize.normal,
                        compact: true,
                        buttonText: 'Delete Request',
                        backgroundColor: kWhite,
                        fontColor: kRed,
                        outlineColor: kRed,
                        radius: 25,
                        height: 42,
                        onTap: onDelete == null
                            ? null
                            : () async => onDelete!(),
                      )
                    else
                      _StatusDot(device: device),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.device});

  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    final approved = device.isApproved;
    final rejected = device.isRejected || device.isBlocked;
    final color = approved
        ? kPrimaryColor
        : rejected
        ? kredColor
        : kYellowColorLight;
    final label = approved
        ? 'Approved'
        : rejected
        ? 'Rejected'
        : device.statusLabel;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        AppText.p2(label, color: color, weight: FontWeight.w500),
      ],
    );
  }
}
