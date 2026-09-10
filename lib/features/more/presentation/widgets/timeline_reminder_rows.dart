import 'package:flutter/material.dart';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';

class TimelineReminderRows extends StatelessWidget {
  const TimelineReminderRows({super.key, required this.logs});

  final List<ReminderLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _ReminderRow(log: logs[i]),
          ],
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.log});

  final ReminderLog log;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: CommonImageView(
                  imagePath: Assets.imagesReminderClock,
                  height: 16,
                  width: 16,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppText.p2(
            '${_paddedTime(log.firedAt)} - ${log.timelineLabel}',
            align: TextAlign.left,
            color: kGreyColor,
            weight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  static String _paddedTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }
}
