import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/more/services/reminder_engine.dart';

enum TimelineSortMode {
  newestFirst,
  oldestFirst,
  editedFirst,
  remindersFirst;

  String get label => switch (this) {
    TimelineSortMode.newestFirst => 'Newest first',
    TimelineSortMode.oldestFirst => 'Oldest first',
    TimelineSortMode.editedFirst => 'Edited first',
    TimelineSortMode.remindersFirst => 'Reminders first',
  };
}

class TimelineSort {
  TimelineSort._();

  static List<T> events<T>({
    required List<T> events,
    required TimelineSortMode mode,
    required DateTime Function(T event) time,
    required bool Function(T event) isEdited,
  }) {
    final sorted = [...events];
    switch (mode) {
      case TimelineSortMode.newestFirst:
      case TimelineSortMode.remindersFirst:
        sorted.sort((a, b) => time(b).compareTo(time(a)));
      case TimelineSortMode.oldestFirst:
        sorted.sort((a, b) => time(a).compareTo(time(b)));
      case TimelineSortMode.editedFirst:
        sorted.sort((a, b) {
          final byEdited = (isEdited(b) ? 1 : 0).compareTo(isEdited(a) ? 1 : 0);
          if (byEdited != 0) return byEdited;
          return time(b).compareTo(time(a));
        });
    }
    return sorted;
  }

  static List<ReminderTimelineItem> mixed({
    required List<ReminderTimelineItem> items,
    required TimelineSortMode mode,
    required bool Function(int punchIndex) isEdited,
  }) {
    if (mode == TimelineSortMode.newestFirst) return items;
    if (mode == TimelineSortMode.oldestFirst) {
      return items.reversed.toList(growable: false);
    }

    int reminderScore(ReminderTimelineItem item) {
      if (!item.isPunch) return 2;
      if (item.attachedLogs.isNotEmpty) return 1;
      return 0;
    }

    final punches = [
      for (final item in items)
        if (item.isPunch) item,
    ]..sort((a, b) {
      if (mode == TimelineSortMode.remindersFirst) {
        final byReminder = reminderScore(b).compareTo(reminderScore(a));
        if (byReminder != 0) return byReminder;
      } else {
        final byEdited = (isEdited(b.punchIndex!) ? 1 : 0).compareTo(
          isEdited(a.punchIndex!) ? 1 : 0,
        );
        if (byEdited != 0) return byEdited;
      }
      return b.time.compareTo(a.time);
    });
    final reminders = [
      for (final item in items)
        if (!item.isPunch) item,
    ];
    return [...reminders, ...punches];
  }
}

class TimelineSortButton extends StatelessWidget {
  const TimelineSortButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TimelineSortMode value;
  final ValueChanged<TimelineSortMode> onChanged;

  static const _itemHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TimelineSortMode>(
      tooltip: 'Sort timeline',
      offset: const Offset(0, 36),
      padding: EdgeInsets.zero,
      color: kWhite,
      constraints: const BoxConstraints(minWidth: 188),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderColor),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final mode in TimelineSortMode.values)
          PopupMenuItem<TimelineSortMode>(
            value: mode,
            height: _itemHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: _itemHeight,
              child: Row(
                children: [
                  Expanded(
                    child: AppText.p2(
                      mode.label,
                      align: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      weight: mode == value ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: mode == value
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: kPrimaryColor,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText.p2('Sort by', color: kGreyColor, weight: FontWeight.w500),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: kGreyColor),
        ],
      ),
    );
  }
}
