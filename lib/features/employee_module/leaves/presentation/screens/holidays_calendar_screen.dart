import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/employee_module/leaves/data/mock/leaves_mock_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/widgets/back_button.dart';

class HolidaysCalendarScreen extends StatelessWidget {
  const HolidaysCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final holidays = LeavesMockStore.instance.holidays;
    final grouped = <int, List<LeaveHoliday>>{};
    for (final holiday in holidays) {
      grouped.putIfAbsent(holiday.date.year, () => []).add(holiday);
    }
    final years = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.page(context),
        child: Column(
          children: [
            const BackButtonBg(
              title: 'Holidays Calendar',
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
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
