import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/my_button.dart';
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

  int selectedDay = 1;
  int selectedMonth = 0;
  int selectedYear = 2000;

  DateTime get _now => DateTime.now();

  DateTime get _nowDay => DateTime(_now.year, _now.month, _now.day);

  DateTime get _minDay {
    final min = widget.minDate;
    if (min == null) return DateTime(1800, 1, 1);
    return DateTime(min.year, min.month, min.day);
  }

  int get _minYear => _minDay.year;
  int get _maxYear => _nowDay.year;

  int get _monthMinIndex {
    if (selectedYear == _minDay.year) return _minDay.month - 1;
    return 0;
  }

  int get _monthMaxIndex {
    if (selectedYear == _nowDay.year) return _nowDay.month - 1;
    return 11;
  }

  int get _daysInSelectedMonth =>
      DateTime(selectedYear, selectedMonth + 1, 0).day;

  int get _dayMin {
    if (selectedYear == _minDay.year && selectedMonth + 1 == _minDay.month) {
      return _minDay.day;
    }
    return 1;
  }

  int get _dayMax {
    final daysInMonth = _daysInSelectedMonth;
    if (selectedYear == _nowDay.year && selectedMonth + 1 == _nowDay.month) {
      return _nowDay.day.clamp(1, daysInMonth);
    }
    return daysInMonth;
  }

  @override
  void initState() {
    selectedDay = widget.initialDate.day;
    selectedMonth = widget.initialDate.month - 1;
    selectedYear = widget.initialDate.year;
    _clampToAllowedRange();
    super.initState();
  }

  void _clampToAllowedRange() {
    if (selectedYear < _minYear) selectedYear = _minYear;
    if (selectedYear > _maxYear) selectedYear = _maxYear;

    final minM = _monthMinIndex;
    final maxM = _monthMaxIndex;
    if (selectedMonth < minM) selectedMonth = minM;
    if (selectedMonth > maxM) selectedMonth = maxM;

    final minD = _dayMin;
    final maxD = _dayMax;
    if (selectedDay < minD) selectedDay = minD;
    if (selectedDay > maxD) selectedDay = maxD;
  }

  static const double _wheelHeight = 176;

  Widget wheel({
    required int min,
    required int max,
    required int initial,
    required Function(int) onChanged,
    required double height,
    List<String>? labels,
    Key? key,
    double width = 100,
  }) {
    final count = max - min + 1;
    if (count <= 0) {
      return SizedBox(width: width, height: height);
    }

    final clampedInitial = initial.clamp(min, max);

    final controller = FixedExtentScrollController(
      initialItem: clampedInitial - min,
    );

    return SizedBox(
      key: key,
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (val) {
              onChanged(min + val);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) {
                final text = labels != null
                    ? labels[index]
                    : (min + index).toString();
                return Center(child: AppText.p1(text, weight: FontWeight.w500));
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthMin = _monthMinIndex;
    final monthMax = _monthMaxIndex;
    final monthLabels = months.sublist(monthMin, monthMax + 1);
    final dayMin = _dayMin;
    final dayMax = _dayMax;

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
                    child: Icon(Icons.close),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 42),
            SizedBox(
              height: _wheelHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  wheel(
                    key: ValueKey(
                      'day-$selectedYear-$selectedMonth-$dayMin-$dayMax',
                    ),
                    min: dayMin,
                    max: dayMax,
                    initial: selectedDay.clamp(dayMin, dayMax),
                    width: 72,
                    height: _wheelHeight,
                    onChanged: (v) => selectedDay = v,
                  ),
                  wheel(
                    key: ValueKey('month-$selectedYear-$monthMin-$monthMax'),
                    min: monthMin,
                    max: monthMax,
                    initial: selectedMonth.clamp(monthMin, monthMax),
                    labels: monthLabels,
                    width: 130,
                    height: _wheelHeight,
                    onChanged: (v) {
                      setState(() {
                        selectedMonth = v;
                        _clampToAllowedRange();
                      });
                    },
                  ),
                  wheel(
                    key: ValueKey('year-$_minYear-$_maxYear'),
                    min: _minYear,
                    max: _maxYear,
                    initial: selectedYear.clamp(_minYear, _maxYear),
                    width: 88,
                    height: _wheelHeight,
                    onChanged: (v) {
                      setState(() {
                        selectedYear = v;
                        _clampToAllowedRange();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
                        selectedDay = widget.initialDate.day;
                        selectedMonth = widget.initialDate.month - 1;
                        selectedYear = widget.initialDate.year;
                        _clampToAllowedRange();
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
                      _clampToAllowedRange();
                      final picked = DateTime(
                        selectedYear,
                        selectedMonth + 1,
                        selectedDay,
                      );
                      widget.onSelected(picked);
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
}
