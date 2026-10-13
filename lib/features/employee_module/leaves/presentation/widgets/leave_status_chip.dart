import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';

class LeaveStatusChip extends StatelessWidget {
  const LeaveStatusChip({super.key, required this.status});

  final LeaveRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      LeaveRequestStatus.pending => (
          const Color(0xFFFFF4E5),
          const Color(0xFFD4920A),
        ),
      LeaveRequestStatus.approved => (
          const Color(0xFFE6F8EF),
          kPrimaryColor,
        ),
      LeaveRequestStatus.rejected => (
          const Color(0xFFFFE8EA),
          kredColor,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText.caption(
        LeaveFormat.statusLabel(status),
        color: fg,
        weight: FontWeight.w600,
      ),
    );
  }
}
