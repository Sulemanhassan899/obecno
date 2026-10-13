import 'package:flutter/material.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/monthly_picker.dart';
import 'package:obecno/widgets/my_button.dart';

/// Result of leave-history duration picker: single day, range, or cleared.
class LeaveHistoryDateRange {
  const LeaveHistoryDateRange({required DateTime start, DateTime? end})
    : start = start,
      end = end ?? start,
      isCleared = false;

  const LeaveHistoryDateRange.cleared()
    : start = null,
      end = null,
      isCleared = true;

  final DateTime? start;
  final DateTime? end;
  final bool isCleared;

  bool get isSingleDay =>
      !isCleared &&
      start != null &&
      end != null &&
      start!.year == end!.year &&
      start!.month == end!.month &&
      start!.day == end!.day;
}

/// Same look as [DateMonthYearPickerSheet], with single-day or range selection.
class LeaveHistoryDatePickerSheet {
  LeaveHistoryDatePickerSheet._();

  static Future<LeaveHistoryDateRange?> show(
    BuildContext context, {
    DateTime? initialStart,
    DateTime? initialEnd,
    DateTime? minDate,
  }) {
    return AppSheet.show<LeaveHistoryDateRange>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Wrap(
          children: [
            _LeaveHistoryDatePickerContent(
              initialStart: initialStart,
              initialEnd: initialEnd,
              minDate: minDate,
            ),
          ],
        );
      },
    );
  }
}

class _LeaveHistoryDatePickerContent extends StatefulWidget {
  const _LeaveHistoryDatePickerContent({
    this.initialStart,
    this.initialEnd,
    this.minDate,
  });

  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime? minDate;

  @override
  State<_LeaveHistoryDatePickerContent> createState() =>
      _LeaveHistoryDatePickerContentState();
}

class _LeaveHistoryDatePickerContentState
    extends State<_LeaveHistoryDatePickerContent> {
  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _weekRows = 6;
  static const _weekRowExtent = 48.0;

  late DateTime? _rangeStart;
  late DateTime? _rangeEnd;
  late DateTime _visibleMonth;
  late final PageController _pageController;

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
    final start = widget.initialStart;
    _rangeStart = start == null
        ? null
        : DateTime(start.year, start.month, start.day);
    final end = widget.initialEnd;
    _rangeEnd = end == null
        ? null
        : DateTime(end.year, end.month, end.day);
    if (_rangeEnd != null &&
        _rangeStart != null &&
        _isSameDay(_rangeStart!, _rangeEnd!)) {
      _rangeEnd = null;
    }
    _visibleMonth = DateTime(
      (_rangeStart ?? _nowDay).year,
      (_rangeStart ?? _nowDay).month,
    );
    _clampVisible();
    _pageController = PageController(initialPage: _indexOf(_visibleMonth));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _clampVisible() {
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

  int get _monthCount {
    return (_maxMonth.year - _minMonth.year) * 12 +
        (_maxMonth.month - _minMonth.month) +
        1;
  }

  int _indexOf(DateTime month) {
    final index =
        (month.year - _minMonth.year) * 12 + (month.month - _minMonth.month);
    if (_monthCount <= 0) return 0;
    return index.clamp(0, _monthCount - 1);
  }

  DateTime _monthAt(int index) =>
      DateTime(_minMonth.year, _minMonth.month + index);

  void _goToMonth(DateTime month, {bool animate = false}) {
    if (month.isBefore(_minMonth) || month.isAfter(_maxMonth)) return;
    final next = DateTime(month.year, month.month);
    if (next.year != _visibleMonth.year || next.month != _visibleMonth.month) {
      setState(() => _visibleMonth = next);
    }
    final index = _indexOf(next);
    if (!_pageController.hasClients) return;
    if (animate) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else if (_pageController.page?.round() != index) {
      _pageController.jumpToPage(index);
    }
  }

  void _shiftMonth(int delta) {
    _goToMonth(
      DateTime(_visibleMonth.year, _visibleMonth.month + delta),
      animate: true,
    );
  }

  void _onPageChanged(int index) {
    final next = _monthAt(index);
    if (next.year == _visibleMonth.year && next.month == _visibleMonth.month) {
      return;
    }
    setState(() => _visibleMonth = next);
  }

  void _openMonthYearPicker() {
    AppSheet.show<void>(
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
                _goToMonth(DateTime(picked.year, picked.month));
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
    setState(() {
      if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
        _rangeStart = day;
        _rangeEnd = null;
        return;
      }
      // Second tap: complete range (or single if same day).
      if (day.isBefore(_rangeStart!)) {
        _rangeEnd = _rangeStart;
        _rangeStart = day;
      } else if (_isSameDay(day, _rangeStart!)) {
        _rangeEnd = null;
      } else {
        _rangeEnd = day;
      }
    });
  }

  int _leadingBlanks(DateTime month) {
    final weekday = DateTime(month.year, month.month, 1).weekday;
    return weekday % 7;
  }

  int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  bool _isEndpoint(DateTime day) {
    if (_rangeStart != null && _isSameDay(day, _rangeStart!)) return true;
    if (_rangeEnd != null && _isSameDay(day, _rangeEnd!)) return true;
    return false;
  }

  bool _isInRange(DateTime day) {
    if (_rangeStart == null || _rangeEnd == null) return false;
    return !day.isBefore(_rangeStart!) && !day.isAfter(_rangeEnd!);
  }

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
                AppText.h5('Select Date', weight: FontWeight.w600),
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
            SizedBox(
              height: _weekRows * _weekRowExtent,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _monthCount,
                itemBuilder: (_, index) => _dayGrid(_monthAt(index)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MyButton(
                    width: double.infinity,
                    size: MyButtonSize.normal,
                    backgroundColor: kWhite,
                    outlineColor: kBorderColor,
                    buttonText: 'Reset',
                    fontColor: kBlack,
                    onTap: () async {
                      setState(() {
                        _rangeStart = null;
                        _rangeEnd = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MyButton(
                    width: double.infinity,
                    buttonText: 'Done',
                    onTap: () async {
                      final start = _rangeStart;
                      if (start == null) {
                        // Reset → Done clears the duration filter.
                        Navigator.pop(
                          context,
                          const LeaveHistoryDateRange.cleared(),
                        );
                        return;
                      }
                      final end = _rangeEnd ?? start;
                      Navigator.pop(
                        context,
                        LeaveHistoryDateRange(start: start, end: end),
                      );
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

  Widget _dayGrid(DateTime month) {
    return Column(
      children: [
        for (var row = 0; row < _weekRows; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _dayCell(month, row * 7 + col)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(DateTime month, int index) {
    final daysInMonth = _daysInMonth(month);
    final dayNumber = index - _leadingBlanks(month) + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 40);
    }

    final day = DateTime(month.year, month.month, dayNumber);
    final enabled = _isEnabled(day);
    final endpoint = _isEndpoint(day);
    final inRange = _isInRange(day);
    final today = _isSameDay(day, _nowDay);
    final isStart =
        _rangeStart != null && _isSameDay(day, _rangeStart!);
    final isEnd = _rangeEnd != null && _isSameDay(day, _rangeEnd!);
    final showRangeBand =
        inRange && _rangeStart != null && _rangeEnd != null;

    Color textColor = kBlack;
    if (!enabled) {
      textColor = kGreyColor3;
    } else if (endpoint) {
      textColor = kWhite;
    }

    return ButtonAnimations.press(
      onTap: enabled ? () => _select(day) : null,
      child: SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showRangeBand)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 40,
                    margin: EdgeInsets.only(
                      left: isStart ? 20 : 0,
                      right: isEnd ? 20 : 0,
                    ),
                    color: kPrimaryColor2,
                  ),
                ),
              ),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: endpoint ? kPrimaryColor : kTransperentColor,
                border: !endpoint && !inRange && today && enabled
                    ? Border.all(color: kPrimaryColor, width: 1.5)
                    : null,
              ),
              child: AppText.p2(
                '$dayNumber',
                color: textColor,
                weight: endpoint ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
