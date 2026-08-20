import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class MonthYearContent extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onSelected;

  /// Earliest selectable calendar month (employee joining month).
  /// Selectable range is always: joining month → current month.
  final DateTime? minDate;

  const MonthYearContent({
    required this.initialDate,
    required this.onSelected,
    this.minDate,
  });

  @override
  State<MonthYearContent> createState() => MonthYearContentState();
}

class MonthYearContentState extends State<MonthYearContent> {
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

  int selectedMonth = 0;
  int selectedYear = 2000;

  DateTime get _nowMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  DateTime get _minMonth {
    final min = widget.minDate;
    if (min == null) return DateTime(1800, 1);
    return DateTime(min.year, min.month);
  }

  int get _minYear => _minMonth.year;
  int get _maxYear => _nowMonth.year;

  /// Inclusive month index (0–11) lower bound for [selectedYear].
  int get _monthMinIndex {
    if (selectedYear == _minMonth.year) return _minMonth.month - 1;
    return 0;
  }

  /// Inclusive month index (0–11) upper bound for [selectedYear].
  int get _monthMaxIndex {
    if (selectedYear == _nowMonth.year) return _nowMonth.month - 1;
    return 11;
  }

  @override
  void initState() {
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
  }) {
    final count = max - min + 1;
    if (count <= 0) {
      return SizedBox(width: 120, height: height);
    }

    final clampedInitial = initial.clamp(min, max);

    final controller = FixedExtentScrollController(
      initialItem: clampedInitial - min,
    );

    return SizedBox(
      key: key,
      width: 120,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 6),
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
                AppText.h5("Select Month & Year", weight: FontWeight.w600),
                ButtonAnimations.press(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: _wheelHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  wheel(
                    key: ValueKey('month-$selectedYear-$monthMin-$monthMax'),
                    min: monthMin,
                    max: monthMax,
                    initial: selectedMonth.clamp(monthMin, monthMax),
                    labels: monthLabels,
                    height: _wheelHeight,
                    onChanged: (v) => selectedMonth = v,
                  ),
                  const SizedBox(width: 24),
                  wheel(
                    key: ValueKey('year-$_minYear-$_maxYear'),
                    min: _minYear,
                    max: _maxYear,
                    initial: selectedYear.clamp(_minYear, _maxYear),
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
            const SizedBox(height: 20),
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
                      final picked = DateTime(selectedYear, selectedMonth + 1);
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
