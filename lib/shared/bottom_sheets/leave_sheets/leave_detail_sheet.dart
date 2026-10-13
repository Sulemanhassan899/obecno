import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/leaves/data/mock/leaves_mock_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/apply_leave_sheet.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_status_chip.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_timeline_cards.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

class LeaveDetailSheet extends StatefulWidget {
  const LeaveDetailSheet({super.key, required this.requestId, this.headerDate});

  final String requestId;
  final DateTime? headerDate;

  static Future<void> show(
    BuildContext context, {
    required String requestId,
    DateTime? headerDate,
  }) {
    return AppSheet.show(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ConstrainedBox(
          constraints: AppSheetSize.constraintsOf(context),
          child: LeaveDetailSheet(requestId: requestId, headerDate: headerDate),
        );
      },
    );
  }

  @override
  State<LeaveDetailSheet> createState() => _LeaveDetailSheetState();
}

class _LeaveDetailSheetState extends State<LeaveDetailSheet> {
  LeaveRequest? get _request =>
      LeavesMockStore.instance.requestById(widget.requestId);

  Future<void> _delete() async {
    final ok = LeavesMockStore.instance.deleteLeave(widget.requestId);
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _edit() async {
    final request = _request;
    if (request == null || !request.isPending) return;
    Navigator.pop(context);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await ApplyLeaveSheet.show(context, existing: request);
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (request == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: AppText.p2('Leave not found'),
      );
    }

    final headerDate = widget.headerDate ?? request.startDate;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: AppText.h5(
                  LeaveFormat.headerFull(headerDate),
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
              ),
              ButtonAnimations.press(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 22),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: kBorderColor),
        Flexible(
          child: ColoredBox(
            color: kbackground1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryCard(request),
                  const SizedBox(height: 12),
                  _detailsCard(request),
                  const SizedBox(height: 20),
                  AppText.h5(
                    'Timeline',
                    weight: FontWeight.w600,
                    align: TextAlign.left,
                  ),
                  const SizedBox(height: 12),
                  LeaveTimelineCards(events: request.timeline),
                ],
              ),
            ),
          ),
        ),
        if (request.isPending) ...[
          const Divider(height: 1, thickness: 1, color: kBorderColor),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottom),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MyButton(
                  width: 130,
                  height: 44,
                  size: MyButtonSize.normal,
                  buttonText: 'Delete',
                  backgroundColor: kredColor,
                  fontColor: kWhite,
                  onTap: _delete,
                ),
                const SizedBox(width: 12),
                MyButton(
                  width: 130,
                  height: 44,
                  size: MyButtonSize.normal,
                  buttonText: 'Edit',
                  backgroundColor: kWhite,
                  fontColor: kBlack,
                  outlineColor: kBorderColor,
                  hasicon: true,
                  leftWidget: CommonImageView(
                    imagePath: Assets.imagesPen,
                    height: 14,
                  ),
                  onTap: _edit,
                ),
              ],
            ),
          ),
        ] else
          SizedBox(height: 12 + bottom),
      ],
    );
  }

  Widget _summaryCard(LeaveRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.p2(
                      'Leave',
                      color: kGreyColor,
                      weight: FontWeight.w400,
                      align: TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    AppText.h4(
                      request.typeName,
                      color: kPurple,
                      weight: FontWeight.w700,
                      align: TextAlign.left,
                    ),
                  ],
                ),
              ),
              LeaveStatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 10),
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
  }

  Widget _detailsCard(LeaveRequest request) {
    Widget row(String label, Widget value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: AppText.p2(
                label,
                color: kGreyColor,
                weight: FontWeight.w400,
                align: TextAlign.left,
              ),
            ),
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.only(right: 12),
              color: kBorderColor,
            ),
            Expanded(child: value),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            'Days',
            AppText.p2(
              LeaveFormat.daysLabel(request.dayCount),
              color: kGreyColor,

              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          row(
            'Dates',
            AppText.p2(
              color: kGreyColor,

              LeaveFormat.range(request.startDate, request.endDate),
              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          row(
            'Type',
            AppText.p2(
              color: kGreyColor,

              request.typeName,
              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          row(
            'Document',
            Row(
              children: [
                Expanded(
                  child: AppText.p2(
                    color: kGreyColor,

                    request.documentName ?? '--',
                    weight: FontWeight.w400,
                    align: TextAlign.left,
                  ),
                ),
                if (request.documentName != null)
                  AppText.p2('View', color: kBlack, weight: FontWeight.w400),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.p2(
                  'Note',
                  color: kGreyColor,
                  weight: FontWeight.w400,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 6),
                AppText.p2(
                  request.note,
                  color: kGreyColor,

                  weight: FontWeight.w400,
                  align: TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
