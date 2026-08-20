import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CheckInOutTimingSheet {
  CheckInOutTimingSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CheckInOutTimingSheetBody(),
    );
  }
}

class _CheckInOutTimingSheetBody extends StatefulWidget {
  const _CheckInOutTimingSheetBody();

  @override
  State<_CheckInOutTimingSheetBody> createState() =>
      _CheckInOutTimingSheetBodyState();
}

class _CheckInOutTimingSheetBodyState
    extends State<_CheckInOutTimingSheetBody> {
  TimeOfDay _checkIn = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _checkOut = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _initialCheckIn = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _initialCheckOut = const TimeOfDay(hour: 17, minute: 0);
  String? _editingField;
  int _graceMinutes = 5;
  int _initialGraceMinutes = 5;

  static const _graceOptions = [0, 5, 10, 15, 30];

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$min $period';
  }

  String _workingHoursLabel() {
    final now = DateTime.now();
    var start = DateTime(
      now.year,
      now.month,
      now.day,
      _checkIn.hour,
      _checkIn.minute,
    );
    var end = DateTime(
      now.year,
      now.month,
      now.day,
      _checkOut.hour,
      _checkOut.minute,
    );
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final diff = end.difference(start);
    return '${diff.inHours}h ${diff.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
  }

  void _reset() {
    setState(() {
      _checkIn = _initialCheckIn;
      _checkOut = _initialCheckOut;
      _graceMinutes = _initialGraceMinutes;
      _editingField = null;
    });
  }

  Future<void> _save() async {
    _initialCheckIn = _checkIn;
    _initialCheckOut = _checkOut;
    _initialGraceMinutes = _graceMinutes;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      ToastHelper.changesSaved(rootContext);
    });
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
                      'Check In / Out Timing',
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
                        'Check-in allowed from office start time, check-out at end time.',
                        color: kGreyColor,
                        weight: FontWeight.w400,
                        align: TextAlign.left,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Column(
                        children: [
                          _TimingRow(
                            title: 'Check-in',
                            value: _formatTime(_checkIn),
                            valueColor: kPrimaryColor,
                            isLast: false,
                            isEditing: _editingField == 'checkin',
                            onTap: () => setState(() {
                              _editingField = _editingField == 'checkin'
                                  ? null
                                  : 'checkin';
                            }),
                            picker: _editingField == 'checkin'
                                ? _TimeWheel(
                                    value: _checkIn,
                                    onChanged: (v) =>
                                        setState(() => _checkIn = v),
                                  )
                                : null,
                          ),
                          _TimingRow(
                            title: 'Check-out',
                            value: _formatTime(_checkOut),
                            valueColor: kredColor,
                            isLast: true,
                            isEditing: _editingField == 'checkout',
                            onTap: () => setState(() {
                              _editingField = _editingField == 'checkout'
                                  ? null
                                  : 'checkout';
                            }),
                            picker: _editingField == 'checkout'
                                ? _TimeWheel(
                                    value: _checkOut,
                                    onChanged: (v) =>
                                        setState(() => _checkOut = v),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: kbackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppText.p2('Working hours'),
                          AppText.p2(_workingHoursLabel()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppText.h6('Grace Period', align: TextAlign.left),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _graceOptions.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, color: kDividerColor),
                            _GraceTile(
                              label: _graceOptions[i] == 0
                                  ? 'No grace'
                                  : '${_graceOptions[i]} mins',
                              selected: _graceMinutes == _graceOptions[i],
                              onTap: () => setState(
                                () => _graceMinutes = _graceOptions[i],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppText.p1(
                      'Define grace minutes for late check-in or early check-out.',
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

class _TimingRow extends StatelessWidget {
  const _TimingRow({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.isLast,
    required this.isEditing,
    required this.onTap,
    this.picker,
  });

  final String title;
  final String value;
  final Color valueColor;
  final bool isLast;
  final bool isEditing;
  final VoidCallback onTap;
  final Widget? picker;

  @override
  Widget build(BuildContext context) {
    // Same timeline row pattern as AddAttendanceBottomSheet.timelineItem:
    // [dot + line]  Label ………  colored time  [pen]
    final lineHeight = isEditing ? 220.0 : 36.0;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const Icon(Icons.circle, color: kDividerColor, size: 12),
                if (!isLast)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 2,
                    height: lineHeight,
                    color: kDividerColor,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Row(
                      children: [
                        AppText.p2(
                          title,
                          color: kSubText,
                          weight: FontWeight.w400,
                          align: TextAlign.left,
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.all(isEditing ? 12 : 0),
                          decoration: BoxDecoration(
                            color: isEditing ? kbackground : kTransperentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AppText.p1(
                            value,
                            color: valueColor,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CommonImageView(
                          imagePath: Assets.imagesPen,
                          height: 16,
                        ),
                      ],
                    ),
                  ),
                  if (picker != null) ...[const SizedBox(height: 8), picker!],
                  if (!isLast) const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({required this.value, required this.onChanged});

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    var selectedHour = value.hourOfPeriod;
    var selectedMinute = value.minute;
    var selectedPeriod = value.period == DayPeriod.am ? 0 : 1;

    void emit() {
      final hour = selectedPeriod == 0
          ? (selectedHour % 12)
          : ((selectedHour % 12) + 12) % 24;
      onChanged(TimeOfDay(hour: hour, minute: selectedMinute));
    }

    return SizedBox(
      height: 180,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _wheel(12, selectedHour % 12, (v) {
            selectedHour = v == 0 ? 12 : v;
            emit();
          }),
          _wheel(60, selectedMinute, (v) {
            selectedMinute = v;
            emit();
          }),
          _wheel(2, selectedPeriod, (v) {
            selectedPeriod = v;
            emit();
          }, labels: const ['AM', 'PM']),
        ],
      ),
    );
  }

  Widget _wheel(
    int max,
    int initial,
    ValueChanged<int> onChanged, {
    List<String>? labels,
  }) {
    final isLooping = labels == null;
    final controller = FixedExtentScrollController(
      initialItem: isLooping ? (1000 * max + initial) : initial,
    );
    return SizedBox(
      width: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            perspective: 0.0025,
            diameterRatio: 1.4,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (val) {
              final realIndex = isLooping ? (val % max) : val;
              HapticFeedback.selectionClick();
              onChanged(realIndex);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: isLooping ? null : max,
              builder: (context, index) {
                final realIndex = isLooping ? (index % max) : index;
                final text = labels != null
                    ? labels[realIndex]
                    : realIndex.toString().padLeft(2, '0');
                return Center(child: AppText.p1(text, weight: FontWeight.w500));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GraceTile extends StatelessWidget {
  const _GraceTile({
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
              child: AppText.p1(label, color: kBlack, align: TextAlign.left),
            ),
            if (selected)
              const Icon(Icons.check, color: kPrimaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
