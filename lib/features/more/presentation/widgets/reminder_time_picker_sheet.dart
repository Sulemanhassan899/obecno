import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/widgets/my_button.dart';

class ReminderTimePickerSheet {
  ReminderTimePickerSheet._();

  static Future<TimeOfDay?> show(
    BuildContext context, {
    required TimeOfDay initial,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReminderTimePickerBody(initial: initial),
    );
  }
}

class _ReminderTimePickerBody extends StatefulWidget {
  const _ReminderTimePickerBody({required this.initial});

  final TimeOfDay initial;

  @override
  State<_ReminderTimePickerBody> createState() =>
      _ReminderTimePickerBodyState();
}

class _ReminderTimePickerBodyState extends State<_ReminderTimePickerBody> {
  late TimeOfDay _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  DateTime _asDate(TimeOfDay time) =>
      DateTime(2020, 1, 1, time.hour, time.minute);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              AppText.h6('Remind me at', weight: FontWeight.w600),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  initialDateTime: _asDate(_selected),
                  minimumDate: _asDate(const TimeOfDay(hour: 0, minute: 0)),
                  maximumDate: _asDate(const TimeOfDay(hour: 23, minute: 59)),
                  onDateTimeChanged: (value) {
                    setState(() {
                      _selected = TimeOfDay(
                        hour: value.hour,
                        minute: value.minute,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              MyButton(
                buttonText: 'Done',
                backgroundColor: kPrimaryButtonColor,
                onTap: () async => Navigator.pop(context, _selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
