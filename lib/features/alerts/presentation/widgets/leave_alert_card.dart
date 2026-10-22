import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/manager_leave_detail_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

/// Leave row on Alerts — manager actions while pending; employee is read-only.
class LeaveAlertCard extends StatelessWidget {
  const LeaveAlertCard({
    super.key,
    required this.item,
    this.busy = false,
    this.highlighted = false,
    this.isEmployeeView = false,
    this.onApprove,
    this.onReject,
    this.onOpen,
  });

  final ManagerTeamLeaveItem item;
  final bool busy;
  final bool highlighted;
  final bool isEmployeeView;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onOpen;

  static final _requestedFormat = DateFormat('MMM d, yyyy');

  String? _photoFor(BuildContext context) {
    final direct = item.employeePhoto?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final employees = context.watch<ManagerEmployeesProvider>().members;
    final userId = item.userId;
    if (userId != null) {
      for (final member in employees) {
        if (member.userId == userId) {
          final photo = member.photo?.trim();
          if (photo != null && photo.isNotEmpty) return photo;
        }
      }
    }
    final name = (item.employeeName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final member in employees) {
      if (member.name.trim().toLowerCase() == name) {
        final photo = member.photo?.trim();
        if (photo != null && photo.isNotEmpty) return photo;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final view = ManagerLeaveView.fromTeamItem(item);
    final photo = _photoFor(context);
    final hasPhoto = photo != null && photo.isNotEmpty;
    final isNetwork =
        hasPhoto && (photo.startsWith('http') || photo.startsWith('//'));
    final name = (item.employeeName ?? 'Employee').trim();
    final pending = !isEmployeeView && item.isPendingInInbox;
    final requestedAt =
        ManagerTeamLeaveItem.parseLeaveDate(item.dateFrom) ?? DateTime.now();

    final statusColor = item.isRejectedLeave
        ? kredColor
        : item.countsAsOnLeave
        ? kPrimaryColor
        : kYellowColor;
    final statusLabel = item.isRejectedLeave
        ? 'Rejected'
        : item.countsAsOnLeave
        ? 'Approved'
        : 'Pending';
    final title = isEmployeeView
        ? 'You have requested a leave'
        : '$name has requested a leave';

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? kPrimaryColor : kBorderColor,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: CommonImageView(
                  url: isNetwork ? photo : null,
                  imagePath:
                      isNetwork ? null : (photo ?? Assets.imagesUserimage),
                  height: 40,
                  width: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppText.p1(
                  title,
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
              ),
              if (!pending) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: AppText.caption(
                    statusLabel,
                    color: statusColor,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppText.p2(
                  view.typeName,
                  color: kGreyColor,
                  weight: FontWeight.w400,
                  align: TextAlign.left,
                ),
              ),
              AppText.p2(
                'Requested: ${_requestedFormat.format(requestedAt)}',
                color: kGreyColor,
                weight: FontWeight.w400,
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppText.caption(
            LeaveFormat.rangeWithDays(
              view.startDate,
              view.endDate,
              view.dayCount,
            ),
            color: kGreyColor150,
            align: TextAlign.left,
          ),
          if (pending) ...[
            const SizedBox(height: 14),
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: MyButton(
                      size: MyButtonSize.normal,
                      compact: false,
                      radius: 30,
                      height: 36,
                      buttonText: 'Approve',
                      backgroundColor: kPrimaryColor,
                      fontColor: kWhite,
                      onTap: () async => onApprove?.call(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MyButton(
                      size: MyButtonSize.normal,
                      compact: false,
                      radius: 30,
                      height: 36,
                      buttonText: 'Reject',
                      backgroundColor: kredColor,
                      fontColor: kWhite,
                      onTap: () async => onReject?.call(),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );

    if (onOpen == null) return card;
    return ButtonAnimations.press(onTap: onOpen, child: card);
  }
}
