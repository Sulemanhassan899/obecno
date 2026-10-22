import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/widgets/back_button.dart';

class ManagerEmployeeHolidaysSheet {
  ManagerEmployeeHolidaysSheet._();

  static Future<void> show({
    required BuildContext context,
    required int userId,
    String? employeeName,
  }) {
    return AppSheet.show<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManagerEmployeeHolidaysSheetBody(
        userId: userId,
        employeeName: employeeName,
      ),
    );
  }
}

class _ManagerEmployeeHolidaysSheetBody extends StatefulWidget {
  const _ManagerEmployeeHolidaysSheetBody({
    required this.userId,
    this.employeeName,
  });

  final int userId;
  final String? employeeName;

  @override
  State<_ManagerEmployeeHolidaysSheetBody> createState() =>
      _ManagerEmployeeHolidaysSheetBodyState();
}

class _ManagerEmployeeHolidaysSheetBodyState
    extends State<_ManagerEmployeeHolidaysSheetBody> {
  bool _loading = true;
  String? _error;
  List<LeaveHoliday> _holidays = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, 1, 1);
      final to = DateTime(now.year + 1, 12, 31);
      final res = await bindings.managerEmployeesService.loadEmployeeHolidays(
        userId: widget.userId,
        dateFrom: _ymd(from),
        dateTo: _ymd(to),
      );
      if (!mounted) return;

      final items = (res.success && res.data != null)
          ? res.data!
          : const <HolidayInfo>[];
      final holidays = items
          .map((h) => LeaveHoliday(date: h.date, name: h.name))
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _holidays = holidays;
        _loading = false;
        if (!res.success) {
          _error = 'Could not load holidays';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load holidays';
      });
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final allowedYears = {currentYear, currentYear + 1};
    final holidays = _holidays
        .where((h) => allowedYears.contains(h.date.year))
        .toList();
    final grouped = <int, List<LeaveHoliday>>{};
    for (final holiday in holidays) {
      grouped.putIfAbsent(holiday.date.year, () => []).add(holiday);
    }
    final years = grouped.keys.toList()..sort();

    return ConstrainedBox(
      constraints: AppSheetSize.constraintsOf(context),
      child: Container(
        decoration: const BoxDecoration(
          color: kbackground1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    BackCircleButton(onTap: () => Navigator.pop(context)),
                    Expanded(
                      child: AppText.h5(
                        'Holidays Calendar',
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              Expanded(
                child: ShimmerRefreshIndicator(
                  instagramStyle: true,
                  triggerFraction: 0.40,
                  showOrb: false,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      AppText.p1(
                        'Public holidays',
                        weight: FontWeight.w600,
                        align: TextAlign.left,
                      ),
                      const SizedBox(height: 12),
                      if (_loading && holidays.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: ShimmerProgress()),
                        )
                      else if (_error != null && holidays.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: AppText.p2(_error!, color: kGreyColor),
                          ),
                        )
                      else if (holidays.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: AppText.p2(
                              'No holidays found',
                              color: kGreyColor,
                            ),
                          ),
                        )
                      else
                        for (final year in years) ...[
                          if (year != years.first) ...[
                            const SizedBox(height: 20),
                            AppText.h5(
                              '$year',
                              weight: FontWeight.w600,
                              align: TextAlign.left,
                            ),
                            const SizedBox(height: 12),
                          ],
                          for (final holiday in grouped[year]!) ...[
                            _HolidayCard(holiday: holiday),
                            const SizedBox(height: 10),
                          ],
                        ],
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
}

class _HolidayCard extends StatelessWidget {
  const _HolidayCard({required this.holiday});

  final LeaveHoliday holiday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.p2(
            LeaveFormat.weekdayFull(holiday.date),
            color: kGreyColor,
            weight: FontWeight.w400,
            align: TextAlign.left,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppText.p2(
                  holiday.name,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                ),
              ),
              const SizedBox(width: 12),
              AppText.p2(
                LeaveFormat.daysLabel(holiday.days),
                color: kGreyColor,
                weight: FontWeight.w400,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
