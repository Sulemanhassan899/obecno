import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/widgets/my_button.dart';

/// Confirmed Show filter. [status] is `null` for All types.
class LeaveStatusFilterResult {
  const LeaveStatusFilterResult(this.status);

  final LeaveRequestStatus? status;
}

/// Radio list: All types / Pending / Approved / Rejected.
class LeaveStatusFilterSheet extends StatefulWidget {
  const LeaveStatusFilterSheet({super.key, this.selected});

  final LeaveRequestStatus? selected;

  static Future<LeaveStatusFilterResult?> show(
    BuildContext context, {
    LeaveRequestStatus? selected,
  }) {
    return AppSheet.show<LeaveStatusFilterResult>(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ConstrainedBox(
          constraints: AppSheetSize.constraintsOf(context),
          child: LeaveStatusFilterSheet(selected: selected),
        );
      },
    );
  }

  @override
  State<LeaveStatusFilterSheet> createState() => _LeaveStatusFilterSheetState();
}

class _LeaveStatusFilterSheetState extends State<LeaveStatusFilterSheet> {
  static const _allKey = 'all';

  late String _selectedKey;

  @override
  void initState() {
    super.initState();
    _selectedKey = switch (widget.selected) {
      LeaveRequestStatus.approved => 'approved',
      LeaveRequestStatus.rejected => 'rejected',
      LeaveRequestStatus.pending => 'pending',
      null => _allKey,
    };
  }

  static const _options = <({String key, String label, Color? color})>[
    (key: _allKey, label: 'All types', color: null),
    (key: 'pending', label: 'Pending', color: kYellowColor),
    (key: 'approved', label: 'Approved', color: kPrimaryColor),
    (key: 'rejected', label: 'Rejected', color: kredColor),
  ];

  LeaveRequestStatus? _statusFromKey(String key) {
    return switch (key) {
      'approved' => LeaveRequestStatus.approved,
      'rejected' => LeaveRequestStatus.rejected,
      'pending' => LeaveRequestStatus.pending,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              AppText.h5('Show', weight: FontWeight.w600),
              const Spacer(),
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
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              itemCount: _options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = _options[index];
                final selected = option.key == _selectedKey;
                final accent = option.color ?? kPrimaryColor;
                return ButtonAnimations.press(
                  onTap: () => setState(() => _selectedKey = option.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? accent : kBorderColor,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText.p1(
                            option.label,
                            weight: FontWeight.w500,
                            color: option.color ?? kBlack,
                            align: TextAlign.left,
                          ),
                        ),
                        _LeaveRadioDot(
                          selected: selected,
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: kBorderColor),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottom),
          child: MyButton(
            width: double.infinity,
            buttonText: 'Select',
            backgroundColor: kBlack,
            fontColor: kWhite,
            onTap: () async {
              Navigator.pop(
                context,
                LeaveStatusFilterResult(_statusFromKey(_selectedKey)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LeaveRadioDot extends StatelessWidget {
  const _LeaveRadioDot({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? color : kBorderColor,
          width: 2,
        ),
        color: selected ? color : kWhite,
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: kWhite,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
