import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/monthly_picker.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class DateMonthYearPickerSheet {
  static void show(
    BuildContext context, {
    required DateTime initialDate,
    required Function(DateTime) onSelected,
    DateTime? minDate,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Wrap(
          children: [
            DateMonthYearContent(
              initialDate: initialDate,
              onSelected: onSelected,
              minDate: minDate,
            ),
          ],
        );
      },
    );
  }
}

class DateMonthYearContent extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onSelected;
  final DateTime? minDate;

  const DateMonthYearContent({
    super.key,
    required this.initialDate,
    required this.onSelected,
    this.minDate,
  });

  @override
  State<DateMonthYearContent> createState() => DateMonthYearContentState();
}

class DateMonthYearContentState extends State<DateMonthYearContent> {
  static const months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late DateTime _selected;
  late DateTime _visibleMonth;

  DateTime get _now => DateTime.now();

  DateTime get _nowDay => DateTime(_now.year, _now.month, _now.day);

  DateTime get _minDay {
    final min = widget.minDate;
    if (min == null) return DateTime(_nowDay.year - 5, 1, 1);
    return DateTime(min.year, min.month, min.day);
  }

  DateTime get _minMonth => DateTime(_minDay.year, _minDay.month);

  DateTime get _maxMonth => DateTime(_nowDay.year, _nowDay.month);

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _visibleMonth = DateTime(_selected.year, _selected.month);
    _clampSelection();
  }

  void _clampSelection() {
    if (_selected.isBefore(_minDay)) _selected = _minDay;
    if (_selected.isAfter(_nowDay)) _selected = _nowDay;
    final month = DateTime(_visibleMonth.year, _visibleMonth.month);
    if (month.isBefore(_minMonth)) _visibleMonth = _minMonth;
    if (month.isAfter(_maxMonth)) _visibleMonth = _maxMonth;
  }

  bool get _canGoPrev {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    return !prev.isBefore(_minMonth);
  }

  bool get _canGoNext {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    return !next.isAfter(_maxMonth);
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    setState(() => _visibleMonth = next);
  }

  void _openMonthYearPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Wrap(
          children: [
            MonthYearContent(
              initialDate: _visibleMonth,
              minDate: _minDay,
              onSelected: (picked) {
                final next = DateTime(picked.year, picked.month);
                if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) {
                  return;
                }
                setState(() => _visibleMonth = next);
              },
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isEnabled(DateTime day) =>
      !day.isBefore(_minDay) && !day.isAfter(_nowDay);

  void _select(DateTime day) {
    if (!_isEnabled(day)) return;
    setState(() => _selected = day);
  }

  /// Sunday-first leading blanks for the visible month.
  int get _leadingBlanks {
    final weekday = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    ).weekday;
    return weekday % 7;
  }

  int get _daysInMonth =>
      DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText.h5("Select Date", weight: FontWeight.w600),
                ButtonAnimations.press(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: kBlack),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _monthHeader(),
            const SizedBox(height: 16),
            _weekdayRow(),
            const SizedBox(height: 8),
            _dayGrid(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MyButton(
                    size: MyButtonSize.normal,
                    backgroundColor: kWhite,
                    buttonText: "Reset",
                    fontColor: kBlack,
                    onTap: () async {
                      setState(() {
                        _selected = DateTime(
                          widget.initialDate.year,
                          widget.initialDate.month,
                          widget.initialDate.day,
                        );
                        _visibleMonth = DateTime(
                          _selected.year,
                          _selected.month,
                        );
                        _clampSelection();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MyButton(
                    buttonText: "Done",
                    onTap: () async {
                      _clampSelection();
                      widget.onSelected(_selected);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        _navButton(
          Icons.chevron_left,
          _canGoPrev ? () => _shiftMonth(-1) : null,
        ),
        Expanded(
          child: ButtonAnimations.press(
            onTap: _openMonthYearPicker,
            child: Center(
              child: AppText.h5(
                '${months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _navButton(
          Icons.chevron_right,
          _canGoNext ? () => _shiftMonth(1) : null,
        ),
      ],
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onTap) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: onTap == null ? kGreyColor3 : kBlack),
      ),
    );
  }

  Widget _weekdayRow() {
    return Row(
      children: [
        for (final label in _weekdays)
          Expanded(
            child: Center(
              child: AppText.caption(
                label,
                color: kSubText,
                weight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _dayGrid() {
    final cells = _leadingBlanks + _daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _dayCell(row * 7 + col)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(int index) {
    final dayNumber = index - _leadingBlanks + 1;
    if (dayNumber < 1 || dayNumber > _daysInMonth) {
      return const SizedBox(height: 40);
    }

    final day = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
    final enabled = _isEnabled(day);
    final selected = _isSameDay(day, _selected);
    final today = _isSameDay(day, _nowDay);

    Color textColor = kBlack;
    if (!enabled) {
      textColor = kGreyColor3;
    } else if (selected) {
      textColor = kWhite;
    }

    return Center(
      child: ButtonAnimations.press(
        onTap: enabled ? () => _select(day) : null,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? kPrimaryColor : kTransperentColor,
            border: !selected && today && enabled
                ? Border.all(color: kPrimaryColor, width: 1.5)
                : null,
          ),
          child: AppText.p2(
            '$dayNumber',
            color: textColor,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
