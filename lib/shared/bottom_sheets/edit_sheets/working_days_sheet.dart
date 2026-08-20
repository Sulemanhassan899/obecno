import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class WorkingDaysSheet {
  WorkingDaysSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _WorkingDaysSheetBody(),
    );
  }
}

class _WorkingDaysSheetBody extends StatefulWidget {
  const _WorkingDaysSheetBody();

  @override
  State<_WorkingDaysSheetBody> createState() => _WorkingDaysSheetBodyState();
}

class _WorkingDaysSheetBodyState extends State<_WorkingDaysSheetBody> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late Set<String> _selectedDays;
  late Set<String> _initialDays;
  bool _workingWeekEnabled = true;
  bool _initialWorkingWeekEnabled = true;
  String _startDay = 'Monday';
  String _initialStartDay = 'Monday';
  String _hoursInWeek = '40:00';
  String _initialHoursInWeek = '40:00';
  String _hoursInDay = '08:00';
  String _initialHoursInDay = '08:00';

  @override
  void initState() {
    super.initState();
    _selectedDays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
    _initialDays = Set.from(_selectedDays);
  }

  void _reset() {
    setState(() {
      _selectedDays = Set.from(_initialDays);
      _workingWeekEnabled = _initialWorkingWeekEnabled;
      _startDay = _initialStartDay;
      _hoursInWeek = _initialHoursInWeek;
      _hoursInDay = _initialHoursInDay;
    });
  }

  Future<void> _save() async {
    _initialDays = Set.from(_selectedDays);
    _initialWorkingWeekEnabled = _workingWeekEnabled;
    _initialStartDay = _startDay;
    _initialHoursInWeek = _hoursInWeek;
    _initialHoursInDay = _hoursInDay;

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      ToastHelper.changesSaved(rootContext);
    });
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText.h5(
                          title,
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                      ),
                      ButtonAnimations.press(
                        onTap: () => Navigator.pop(sheetContext),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: kDividerColor),
                ...options.map(
                  (option) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(sheetContext, option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText.p2(
                              option,
                              align: TextAlign.left,
                              weight: FontWeight.w500,
                            ),
                          ),
                          if (option == current)
                            const Icon(
                              Icons.check,
                              color: kPrimaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
    if (result != null && mounted) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.9,
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.h5(
                      'Working Days',
                      weight: FontWeight.w600,
                      align: TextAlign.left,
                    ),
                  ),
                  ButtonAnimations.press(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: kDividerColor),
            Expanded(
              child: Container(
                color: kbackground2,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  children: [
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppText.p1(
                        'Set working days for this location.',
                        color: kGreyColor,
                        align: TextAlign.left,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _days.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, color: kDividerColor),
                            _DayTile(
                              label: _days[i],
                              selected: _selectedDays.contains(_days[i]),
                              onTap: () {
                                setState(() {
                                  if (_selectedDays.contains(_days[i])) {
                                    _selectedDays.remove(_days[i]);
                                  } else {
                                    _selectedDays.add(_days[i]);
                                  }
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppText.h5('Working Week', align: TextAlign.left),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ToggleRow(
                            label: 'Working Days',
                            value: _workingWeekEnabled,
                            onChanged: (v) =>
                                setState(() => _workingWeekEnabled = v),
                          ),
                          const Divider(height: 1, color: kDividerColor),
                          _DropdownRow(
                            label: 'Workweek Start Day',
                            value: _startDay,
                            onTap: () => _pickOption(
                              title: 'Workweek Start Day',
                              options: _days,
                              current: _startDay,
                              onSelected: (v) => setState(() => _startDay = v),
                            ),
                          ),
                          const Divider(height: 1, color: kDividerColor),
                          _DropdownRow(
                            label: 'Hours in a Week',
                            value: _hoursInWeek,
                            onTap: () => _pickOption(
                              title: 'Hours in a Week',
                              options: const [
                                '35:00',
                                '37:30',
                                '40:00',
                                '45:00',
                              ],
                              current: _hoursInWeek,
                              onSelected: (v) =>
                                  setState(() => _hoursInWeek = v),
                            ),
                          ),
                          const Divider(height: 1, color: kDividerColor),
                          _DropdownRow(
                            label: 'Hours in a Day',
                            value: _hoursInDay,
                            onTap: () => _pickOption(
                              title: 'Hours in a Day',
                              options: const [
                                '07:00',
                                '07:30',
                                '08:00',
                                '09:00',
                              ],
                              current: _hoursInDay,
                              onSelected: (v) =>
                                  setState(() => _hoursInDay = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppText.p1(
                      "When enabled, this location's working week will overwrite the global working week.",
                      color: kGreyColor,
                      weight: FontWeight.w400,
                      align: TextAlign.left,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: kDividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: MyButton(
                      size: MyButtonSize.normal,
                      buttonText: 'Reset',
                      backgroundColor: kWhite,
                      fontColor: kBlack,
                      outlineColor: kBorderColor,
                      onTap: () async => _reset(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: MyButton(
                      buttonText: 'Save',
                      backgroundColor: kPrimaryButtonColor,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: AppText.p2(
                label,
                color: kBlack,
                weight: FontWeight.w500,
                align: TextAlign.left,
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: kPrimaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: AppText.p2(
              label,
              color: kBlack,
              weight: FontWeight.w500,
              align: TextAlign.left,
            ),
          ),
          SizedBox(
            width: 55,
            height: 40,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch.adaptive(
                value: value,
                activeColor: kPrimaryColor,
                thumbColor: MaterialStateProperty.all(kWhite),
                trackColor: MaterialStateProperty.all(kPrimaryColor),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: AppText.p2(
                label,
                color: kBlack,
                weight: FontWeight.w500,
                align: TextAlign.left,
              ),
            ),
            AppText.p2(value, color: kGreyColor, weight: FontWeight.w500),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: kGreyColor),
          ],
        ),
      ),
    );
  }
}
