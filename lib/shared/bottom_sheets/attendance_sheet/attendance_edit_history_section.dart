import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

/// Renders the edit-request / response rows under a timeline card
/// (Fix Request Sent, Approved, Rejected). Supports multiple entries.
class AttendanceEditHistorySection extends StatelessWidget {
  const AttendanceEditHistorySection({super.key, required this.requests});

  final List<AttendanceEditRequest> requests;

  static String dateTimeLabel(DateTime d) {
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
    final period = d.hour >= 12 ? 'PM' : 'AM';

    return '${d.day} ${months[d.month - 1]} - ${d.year} $hour:$min$period';
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Divider(height: 1, color: kBorderColor),
        const SizedBox(height: 14),
        ...requests.map((request) {
          switch (request.status) {
            case AttendanceEditRequestStatus.rejected:
              return _StatusRow(
                icon: Assets.imagesXmark,
                title: 'Rejected by : ${request.actionedBy ?? '-'}',
                atLabel: dateTimeLabel(
                  request.actionedAt ?? request.requestedAt,
                ),
                timeLabels: [
                  'Original time : ${request.originalTime}',
                  'New time : ${request.newTime}',
                ],
              );
            case AttendanceEditRequestStatus.approved:
              return _StatusRow(
                icon: Assets.imagesCheck,
                title: 'Approved by : ${request.actionedBy ?? '-'}',
                atLabel: dateTimeLabel(
                  request.actionedAt ?? request.requestedAt,
                ),
                timeLabels: [
                  'Original time : ${request.originalTime}',
                  'New time : ${request.newTime}',
                ],
              );
            case AttendanceEditRequestStatus.pending:
              return _StatusRow(
                icon: Assets.imagesEmail,
                title: 'Fix Request Sent',
                atLabel: dateTimeLabel(request.requestedAt),
                timeLabels: ['New time : ${request.newTime}'],
              );
          }
        }),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.atLabel,
    required this.timeLabels,
  });

  final String icon;
  final String title;
  final String atLabel;
  final List<String> timeLabels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommonImageView(imagePath: icon, height: 12),
              const SizedBox(width: 10),
              Expanded(
                child: AppText.p1(
                  title,
                  color: kSubText,
                  align: TextAlign.left,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: AppText.p2(
              'at  $atLabel',
              color: kSubText,
              align: TextAlign.left,
            ),
          ),
          ...timeLabels.map(
            (label) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  CommonImageView(imagePath: Assets.imagesClockGrey, height: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText.p2(
                      label,
                      color: kSubText,
                      align: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
