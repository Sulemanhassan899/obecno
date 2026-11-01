import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

/// Renders the edit-request / response rows under a timeline card.
///
/// Approved and rejected requests keep the original "Fix Request Sent" row
/// and add a separate outcome row above it, so the full history is visible.
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

  static List<Widget> _rowsFor(AttendanceEditRequest request) {
    final fixRequestRow = _StatusRow(
      icon: Assets.imagesEmail,
      title: 'Fix Request Sent',
      atLabel: dateTimeLabel(request.requestedAt),
      timeLabels: ['New time : ${request.newTime}'],
    );

    switch (request.status) {
      case AttendanceEditRequestStatus.rejected:
        return [
          _StatusRow(
            icon: Assets.imagesXmark,
            title: 'Rejected by : ${request.actionedBy ?? '-'}',
            atLabel: dateTimeLabel(request.actionedAt ?? request.requestedAt),
            timeLabels: ['Original time : ${request.originalTime}'],
          ),
          fixRequestRow,
        ];
      case AttendanceEditRequestStatus.approved:
        return [
          _StatusRow(
            icon: Assets.imagesCheck,
            title: 'Approved by : ${request.actionedBy ?? '-'}',
            atLabel: dateTimeLabel(request.actionedAt ?? request.requestedAt),
            timeLabels: ['Original time : ${request.originalTime}'],
          ),
          fixRequestRow,
        ];
      case AttendanceEditRequestStatus.pending:
        return [fixRequestRow];
    }
  }

  @override
  Widget build(BuildContext context) {
    final unique = _collapseDuplicateRequests(
      AttendanceEditRequest.dedupe(requests),
    );
    if (unique.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Divider(height: 1, color: kBorderColor),
        const SizedBox(height: 14),
        ...unique.expand(_rowsFor),
      ],
    );
  }

  /// Drops a pending "Fix Request Sent" when the same new time was already
  /// approved/rejected, and collapses identical decided rows (API often
  /// returns the same edit in both `changes` and `change_requests`).
  static List<AttendanceEditRequest> _collapseDuplicateRequests(
    List<AttendanceEditRequest> raw,
  ) {
    if (raw.length <= 1) return raw;

    final sorted = List<AttendanceEditRequest>.of(raw)
      ..sort((a, b) {
        if (a.isPending != b.isPending) return a.isPending ? 1 : -1;
        final aAt = a.actionedAt ?? a.requestedAt;
        final bAt = b.actionedAt ?? b.requestedAt;
        return bAt.compareTo(aAt);
      });

    String clockKey(AttendanceEditRequest request, String label) {
      final parsed = AttendanceEditRequest.parseClockTime(
        label,
        date: request.requestedAt,
      );
      if (parsed == null) {
        final trimmed = label.trim().toLowerCase();
        if (trimmed.isEmpty || trimmed == '--') return '--';
        return trimmed;
      }
      if (AttendanceEditRequest.isPlaceholderMint(parsed)) return '--';
      return '${parsed.hour}:${parsed.minute}';
    }

    final decidedNewTimes = <String>{
      for (final request in sorted)
        if (!request.isPending) clockKey(request, request.newTime),
    };

    final out = <AttendanceEditRequest>[];
    final seen = <String>{};
    for (final request in sorted) {
      final newTime = clockKey(request, request.newTime);
      if (request.isPending && decidedNewTimes.contains(newTime)) {
        continue;
      }
      final key = request.isPending
          ? 'pending|$newTime'
          : '${request.status.name}|${clockKey(request, request.originalTime)}|$newTime';
      if (!seen.add(key)) continue;
      out.add(request);
    }
    return out;
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
                  CommonImageView(
                    imagePath: Assets.imagesClockGrey,
                    height: 16,
                  ),
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
