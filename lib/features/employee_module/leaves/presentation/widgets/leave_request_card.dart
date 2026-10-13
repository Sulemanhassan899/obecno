import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_status_chip.dart';

class LeaveRequestCard extends StatelessWidget {
  const LeaveRequestCard({
    super.key,
    required this.request,
    this.onTap,
  });

  final LeaveRequest request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText.p1(
                  request.typeName,
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
              ),
              LeaveStatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          AppText.p2(
            LeaveFormat.rangeWithDays(
              request.startDate,
              request.endDate,
              request.dayCount,
            ),
            color: kGreyColor,
            weight: FontWeight.w400,
            align: TextAlign.left,
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return ButtonAnimations.press(onTap: onTap, child: child);
  }
}
