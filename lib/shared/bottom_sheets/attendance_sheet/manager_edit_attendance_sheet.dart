import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_profile_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class ManagerEditAttendanceSheet {
  ManagerEditAttendanceSheet._();

  static Future<void> show({
    required BuildContext context,
    required ManagerAttendanceDetailsData data,
    bool isAdd = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManagerEditAttendanceSheetBody(data: data, isAdd: isAdd),
    );
  }
}

class _ManagerEditAttendanceSheetBody extends StatelessWidget {
  const _ManagerEditAttendanceSheetBody({
    required this.data,
    required this.isAdd,
  });

  final ManagerAttendanceDetailsData data;
  final bool isAdd;

  String get _checkIn {
    final v = data.checkIn?.trim();
    if (v == null || v.isEmpty) return "--";
    return v;
  }

  String get _checkOut {
    final v = data.checkOut?.trim();
    if (v == null || v.isEmpty) return "--";
    return v;
  }

  bool get _hasCheckIn => _checkIn != "--";
  bool get _hasCheckOut => _checkOut != "--";

  String get _duration => data.durationLabel;

  String get _checkInLocation {
    final v = data.checkInLocation?.trim();
    if (!_hasCheckIn || v == null || v.isEmpty) return "--";
    return v;
  }

  String get _checkOutLocation {
    final v = data.checkOutLocation?.trim();
    if (!_hasCheckOut || v == null || v.isEmpty) return "--";
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Header — date + close
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.h5(
                      ManagerAttendanceDetailsData.formatFullDate(data.day),
                      weight: FontWeight.w600,
                      align: TextAlign.left,
                    ),
                  ),
                  ButtonAnimations.press(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kDividerColor),

            /// User card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  ClipOval(
                    child: CommonImageView(
                      imagePath: data.photo ?? Assets.imagesUserimage,
                      height: 48,
                      width: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText.p2(
                          data.name,
                          color: kBlack,
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                        if (data.role != null &&
                            data.role!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          AppText.caption(
                            data.role!,
                            color: kGreyColor,
                            weight: FontWeight.w400,
                            align: TextAlign.left,
                          ),
                        ],
                      ],
                    ),
                  ),
                  ButtonAnimations.press(
                    onTap: () {
                      ManagerEmployeeProfileSheet.show(
                        context: context,
                        data: data,
                      );
                    },
                    child: CommonImageView(
                      imagePath: Assets.ProfileShareButton,
                      height: 45,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kDividerColor),

            /// Attendance summary card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText.p2("Check-In", color: kPrimaryColor),
                              const SizedBox(height: 6),
                              AppText.h3(
                                _checkIn,
                                align: TextAlign.left,
                                color: _hasCheckIn ? kPrimaryColor : kBlack,
                                weight: FontWeight.w700,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _dot(),
                            _line(),
                            const SizedBox(width: 6),
                            AppText.p2(
                              _duration,
                              weight: FontWeight.w600,
                              color: kGreyColor,
                            ),
                            const SizedBox(width: 6),
                            _line(),
                            _dot(),
                          ],
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppText.p2(
                                "Check-Out",
                                color: _hasCheckOut ? kredColor : kGreyColor,
                              ),
                              const SizedBox(height: 6),
                              AppText.h3(
                                _checkOut,
                                align: TextAlign.right,
                                color: _hasCheckOut ? kredColor : kBlack,
                                weight: FontWeight.w700,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _location(_checkInLocation)),
                        Expanded(
                          child: _location(_checkOutLocation, isRight: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: kDividerColor),

            /// Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: MyButton(
                buttonText: isAdd ? "Add Attendance" : "Save Attendance",
                backgroundColor: kPrimaryColor,
                onTap: () async => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot() =>
      Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3));

  Widget _line() =>
      Container(width: 18, height: 2, color: kGreyColor.withOpacity(0.3));

  Widget _location(String text, {bool isRight = false}) {
    return Row(
      children: [
        if (!isRight)
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
        if (!isRight) const SizedBox(width: 6),
        Expanded(
          child: AppText.caption(
            text,
            color: kGreyColor,
            weight: FontWeight.w500,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            align: isRight ? TextAlign.right : TextAlign.left,
          ),
        ),
        if (isRight) const SizedBox(width: 6),
        if (isRight)
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
      ],
    );
  }
}
