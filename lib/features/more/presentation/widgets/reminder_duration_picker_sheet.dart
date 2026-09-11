import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/widgets/my_button.dart';

class ReminderDurationPickerSheet {
  ReminderDurationPickerSheet._();

  static Future<int?> show(
    BuildContext context, {
    required int initialMinutes,
    required int resetMinutes,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReminderDurationPickerBody(
        initialMinutes: ReminderCopy.snapDuration(initialMinutes),
        resetMinutes: ReminderCopy.snapDuration(resetMinutes),
      ),
    );
  }
}

class _ReminderDurationPickerBody extends StatefulWidget {
  const _ReminderDurationPickerBody({
    required this.initialMinutes,
    required this.resetMinutes,
  });

  final int initialMinutes;
  final int resetMinutes;

  @override
  State<_ReminderDurationPickerBody> createState() =>
      _ReminderDurationPickerBodyState();
}

class _ReminderDurationPickerBodyState
    extends State<_ReminderDurationPickerBody> {
  late int _selected;
  late FixedExtentScrollController _controller;

  List<int> get _options => ReminderCopy.durationOptionsInMinutes;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMinutes;
    final index = _options.indexOf(_selected);
    _controller = FixedExtentScrollController(
      initialItem: index < 0 ? 0 : index,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              AppText.h6('Notify me after', weight: FontWeight.w600),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: CupertinoPicker(
                  scrollController: _controller,
                  itemExtent: 36,
                  magnification: 1.1,
                  useMagnifier: true,
                  onSelectedItemChanged: (index) {
                    setState(() => _selected = _options[index]);
                  },
                  children: [
                    for (final minutes in _options)
                      Center(
                        child: AppText.h6(
                          ReminderCopy.durationPhrase(minutes),
                          weight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MyButton(
                      size: MyButtonSize.normal,
                      buttonText: 'Reset',
                      backgroundColor: kWhite,
                      fontColor: kBlack,
                      outlineColor: kBorderColor,
                      onTap: () async =>
                          Navigator.pop(context, widget.resetMinutes),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: MyButton(
                      buttonText: 'Done',
                      backgroundColor: kPrimaryButtonColor,
                      onTap: () async => Navigator.pop(context, _selected),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
