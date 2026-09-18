import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/services/reminder_engine.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/timeline_sort.dart';

void main() {
  test('oldest first reverses newest-first timeline items', () {
    final newest = [
      ReminderTimelineItem.punch(
        punchIndex: 0,
        time: DateTime(2026, 9, 18, 19, 49),
        attachedLogs: const [],
      ),
      ReminderTimelineItem.punch(
        punchIndex: 1,
        time: DateTime(2026, 9, 18, 15, 2),
        attachedLogs: const [],
      ),
    ];

    final oldest = TimelineSort.mixed(
      items: newest,
      mode: TimelineSortMode.oldestFirst,
      isEdited: (_) => false,
    );

    expect(oldest.first.punchIndex, 1);
    expect(oldest.last.punchIndex, 0);
  });

  test('edited first keeps edited cards above plain punches', () {
    final items = [
      ReminderTimelineItem.punch(
        punchIndex: 0,
        time: DateTime(2026, 9, 18, 19, 49),
        attachedLogs: const [],
      ),
      ReminderTimelineItem.punch(
        punchIndex: 1,
        time: DateTime(2026, 9, 18, 18, 0),
        attachedLogs: const [],
      ),
      ReminderTimelineItem.punch(
        punchIndex: 2,
        time: DateTime(2026, 9, 18, 15, 2),
        attachedLogs: const [],
      ),
    ];

    final sorted = TimelineSort.mixed(
      items: items,
      mode: TimelineSortMode.editedFirst,
      isEdited: (index) => index == 2,
    );

    expect(sorted.first.punchIndex, 2);
  });

  test('reminders first keeps standalone reminder rows above punches', () {
    final items = [
      ReminderTimelineItem.punch(
        punchIndex: 0,
        time: DateTime(2026, 9, 18, 19, 0),
        attachedLogs: const [],
      ),
      ReminderTimelineItem.reminders(
        time: DateTime(2026, 9, 18, 12, 0),
        standaloneLogs: const [],
      ),
    ];

    final sorted = TimelineSort.mixed(
      items: items,
      mode: TimelineSortMode.remindersFirst,
      isEdited: (_) => false,
    );

    expect(sorted.first.isPunch, isFalse);
    expect(sorted.last.punchIndex, 0);
  });
}
