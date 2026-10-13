import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/providers/reminder_settings_provider.dart';

void main() {
  final checkIn = ReminderPunch(
    kind: ReminderPunchKind.checkIn,
    time: DateTime(2026, 10, 13, 22, 42),
  );

  test('live empty clock wins over stale saved checked-in punches', () {
    final resolved = ReminderSettingsProvider.resolveLivePunches(
      fromClock: const [],
      saved: [checkIn],
    );
    expect(resolved, isEmpty);
  });

  test('live clock punches win over a different saved timeline', () {
    final live = [
      ReminderPunch(
        kind: ReminderPunchKind.checkIn,
        time: DateTime(2026, 10, 14, 9, 0),
      ),
    ];
    final resolved = ReminderSettingsProvider.resolveLivePunches(
      fromClock: live,
      saved: [checkIn],
    );
    expect(resolved, live);
  });

  test('saved punches are used only when clock has no session key', () {
    final resolved = ReminderSettingsProvider.resolveLivePunches(
      fromClock: null,
      saved: [checkIn],
    );
    expect(resolved, [checkIn]);
  });
}
