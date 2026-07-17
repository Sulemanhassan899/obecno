// ignore_for_file: non_constant_identifier_names

import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/shared/widgets/bottom_sheet.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

enum TicketResponseStatus { pending, approved, rejected }

class ReponseBottomSheet {
  static void show(
    BuildContext context, {
    required TicketResponseStatus status,

    String time = "--",
    String eventLabel = "Check-In",
    String location = "--",
    DateTime? requestedAt,
    String originalTime = "--",
    String newTime = "--",
    String? actionedBy,
    DateTime? actionedAt,
  }) {
    final now = DateTime.now();

    CommonBottomSheet.show(
      context: context,
      height: MediaQuery.of(context).size.height * 0.45,
      buttonText: "",
      onButtonTap: () {
        // Navigator.pop(context);
      },

      children: [
        _ReponseContent(
          status: status,
          time: time,
          eventLabel: eventLabel,
          location: location,
          requestedAt: requestedAt ?? now, 
          originalTime: originalTime,
          newTime: newTime,
          actionedBy: actionedBy,
          actionedAt: actionedAt,
        ),
      ],
    );
  }
}

class _ReponseContent extends StatelessWidget {
  final TicketResponseStatus status;
  final String time;
  final String eventLabel;
  final String location;
  final DateTime requestedAt;
  final String originalTime;
  final String newTime;
  final String? actionedBy;
  final DateTime? actionedAt;

  const _ReponseContent({
    required this.status,
    required this.time,
    required this.eventLabel,
    required this.location,
    required this.requestedAt,
    required this.originalTime,
    required this.newTime,
    this.actionedBy,
    this.actionedAt,
  });

  String _dateTimeLabel(DateTime d) {
    const months = [
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

    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final min = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? "PM" : "AM";

    return "${d.day} ${months[d.month - 1]} - ${d.year} $hour:${min}$period";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText.h4(time, weight: FontWeight.w700),
            ButtonAnimations.press(
              onTap: () => Navigator.pop(context),
              child: AppText.p2("Edited", color: kSubText),
            ),
          ],
        ),
        const SizedBox(height: 6),

        Row(
          children: [
            AppText.h5(
              eventLabel,
              color: kPrimaryColor,
              weight: FontWeight.w700,
            ),
            const SizedBox(width: 10),
            CommonImageView(imagePath: Assets.imagesUserPen, height: 20),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: kSubText),
            const SizedBox(width: 4),
            AppText.p2(location, color: kSubText),
          ],
        ),

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        if (status == TicketResponseStatus.rejected)
          _StatusRow(
            icon: Assets.imagesXmark,
            title: "Rejected by - ${actionedBy ?? '-'}",
            atLabel: _dateTimeLabel(actionedAt ?? requestedAt),
            subLabel: "Original time - $originalTime",
            subIcon: Assets.imagesClockGrey,
          ),

        if (status == TicketResponseStatus.approved)
          _StatusRow(
            icon: Assets.imagesCheck,
            title: "Approved by - ${actionedBy ?? '-'}",
            atLabel: _dateTimeLabel(actionedAt ?? requestedAt),
            subLabel: "Original time - $originalTime",
            subIcon: Assets.imagesClockGrey,
          ),

        if (status != TicketResponseStatus.pending) const SizedBox(height: 16),

        _StatusRow(
          icon: Assets.imagesEmail,
          title: "Fix Request Sent",
          atLabel: _dateTimeLabel(requestedAt),
          subLabel: "New time - $newTime",
          subIcon: Assets.imagesClockGrey,
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String icon;
  final String title;
  final String atLabel;
  final String subLabel;
  final String subIcon;

  const _StatusRow({
    required this.icon,
    required this.title,
    required this.atLabel,
    required this.subLabel,
    required this.subIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              spacing: 5,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CommonImageView(imagePath: icon, height: 16),
                    const SizedBox(width: 10),
                    AppText.p1(title, weight: FontWeight.w600),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 28),
                    AppText.p2("at  $atLabel", color: kSubText),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CommonImageView(imagePath: subIcon, height: 20),
                    const SizedBox(width: 10),
                    AppText.p2(subLabel, color: kSubText),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
