import 'package:flutter/material.dart';

import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/presentation/widgets/reminder_duration_picker_sheet.dart';
import 'package:obecno/features/more/presentation/widgets/reminder_time_picker_sheet.dart';
import 'package:obecno/features/more/providers/reminder_settings_provider.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/customswitch2.dart';

class AttendanceRemindersScreen extends StatefulWidget {
  const AttendanceRemindersScreen({super.key});

  @override
  State<AttendanceRemindersScreen> createState() =>
      _AttendanceRemindersScreenState();
}

class _AttendanceRemindersScreenState extends State<AttendanceRemindersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReminderSettingsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<ReminderSettingsProvider>();

    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
        child: Padding(
          padding: AppSizes.HORIZONTAL,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const BackButtonBg(title: 'Attendance Reminders'),
              const SizedBox(height: 20),
              Expanded(
                child: ShimmerRefreshIndicator(
                  onRefresh: () =>
                      context.read<ReminderSettingsProvider>().refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      _section(
                        title: 'Check In',
                        child: Column(
                          children: [
                            _reminderCard(
                              title: 'Check In',
                              type: ReminderType.checkIn,
                              reminders: reminders,
                              detailLabel: 'Remind me at',
                              detailValue: reminders.checkInTimeLabel,
                            ),
                            const SizedBox(height: 8),
                            _reminderCard(
                              title: 'Check In Missed',
                              type: ReminderType.checkInMissed,
                              reminders: reminders,
                              detailLabel: 'Remind me at',
                              detailValue: reminders.checkInMissedLabel,
                            ),
                          ],
                        ),
                      ),
                      _section(
                        title: 'Check Out',
                        child: Column(
                          children: [
                            _reminderCard(
                              title: 'Check Out',
                              type: ReminderType.checkOut,
                              reminders: reminders,
                              detailLabel: 'Remind me at',
                              detailValue: reminders.checkOutTimeLabel,
                            ),
                            const SizedBox(height: 8),
                            _reminderCard(
                              title: 'Check Out Missed',
                              type: ReminderType.checkOutMissed,
                              reminders: reminders,
                              detailLabel: 'Remind me at',
                              detailValue: reminders.checkOutMissedLabel,
                            ),
                          ],
                        ),
                      ),
                      _section(
                        title: 'Break',
                        caption:
                            "You'll get a reminder after your break time is over.",
                        child: Column(
                          children: [
                            _reminderCard(
                              title: 'Break time',
                              type: ReminderType.breakTime,
                              reminders: reminders,
                              detailLabel: 'Remind me at',
                              detailValue: reminders.breakTimeLabel,
                            ),
                            const SizedBox(height: 8),
                            _reminderCard(
                              title: 'Break time ended',
                              type: ReminderType.breakTimeEnded,
                              reminders: reminders,
                              detailLabel: 'Remind me at',
                              detailValue: reminders.breakEndedTimeLabel,
                            ),
                            const SizedBox(height: 8),
                            _reminderCard(
                              title: 'Longer break',
                              type: ReminderType.longerBreak,
                              reminders: reminders,
                              detailLabel: 'Remind me after',
                              detailValue: reminders.longerBreakLabel,
                            ),
                          ],
                        ),
                      ),
                      _section(
                        title: 'Attendance Issue',
                        caption: reminders.longAttendanceCaption,
                        child: _reminderCard(
                          title: 'Very long attendance',
                          type: ReminderType.veryLongAttendance,
                          reminders: reminders,
                          detailLabel: 'Notify me after',
                          detailValue: reminders.longAttendanceLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    String? caption,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.h6(title, weight: FontWeight.w600, align: TextAlign.left),
          const SizedBox(height: 10),
          child,
          if (caption != null) ...[
            const SizedBox(height: 8),
            AppText.caption(caption, align: TextAlign.left, color: kGreyColor),
          ],
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _reminderCard({
    required String title,
    required ReminderType type,
    required ReminderSettingsProvider reminders,
    required String detailLabel,
    required String detailValue,
  }) {
    final on = reminders.isEnabled(type);
    final canPick = type.canPickTime || type.canPickDuration;
    return _card(
      children: [
        _toggleRow(label: title, type: type, reminders: reminders),
        if (on) ...[
          _divider(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canPick
                ? () => type.canPickDuration
                      ? _pickDuration(type, reminders)
                      : _pickTime(type, reminders)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.p2(
                      detailLabel,
                      align: TextAlign.left,
                      color: kBlack,
                    ),
                  ),
                  AppText.p2(
                    detailValue,
                    align: TextAlign.right,
                    weight: FontWeight.w400,
                  ),
                  if (canPick) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: kBlack,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTime(
    ReminderType type,
    ReminderSettingsProvider reminders,
  ) async {
    final picked = await ReminderTimePickerSheet.show(
      context,
      initial: reminders.reminderTimeFor(type),
      resetTo: reminders.latestTimeFor(type),
    );
    if (!mounted || picked == null) return;
    await reminders.setReminderTime(type, picked);
  }

  Future<void> _pickDuration(
    ReminderType type,
    ReminderSettingsProvider reminders,
  ) async {
    final picked = await ReminderDurationPickerSheet.show(
      context,
      title: type == ReminderType.veryLongAttendance
          ? 'Notify me after'
          : 'Remind me after',
      initialMinutes: reminders.durationMinutesFor(type),
      resetMinutes: reminders.defaultDurationMinutesFor(type),
    );
    if (!mounted || picked == null) return;
    await reminders.setDuration(type, picked);
  }

  Widget _toggleRow({
    required String label,
    required ReminderType type,
    required ReminderSettingsProvider reminders,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.Poppins,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: kBlack,
                height: 1.35,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CustomSwitch(
            value: reminders.isEnabled(type),
            onChanged: (value) => reminders.setEnabled(type, value),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 1, color: kDividerColor),
    );
  }
}
