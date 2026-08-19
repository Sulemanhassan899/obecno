import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class StatusFilterOption {
  const StatusFilterOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final String icon;

  static const allId = 'all';

  static const all = StatusFilterOption(
    id: allId,
    label: 'All Status',
    icon: Assets.AllStatus,
  );

  static const List<StatusFilterOption> options = [
    all,
    StatusFilterOption(
      id: 'present',
      label: 'Present Today',
      icon: Assets.PresentTodayHandIcon,
    ),
    StatusFilterOption(
      id: 'working',
      label: 'Active / Working',
      icon: Assets.ActivePersonsIcon,
    ),
    StatusFilterOption(
      id: 'break',
      label: 'On Break',
      icon: Assets.OnBreakIcon,
    ),
    StatusFilterOption(
      id: 'late',
      label: 'Late Check-in',
      icon: Assets.EarlyCheckOutInIcon,
    ),
    StatusFilterOption(
      id: 'early_checkout',
      label: 'Early Check-Out',
      icon: Assets.EarlyCheckOutInIcon,
    ),
    StatusFilterOption(
      id: 'absent',
      label: 'Absent',
      icon: Assets.AbsentIcon,
    ),
  ];

  /// Maps overview / legacy labels → status option id.
  static String idFromLabel(String? label) {
    if (label == null || label.trim().isEmpty) return allId;
    switch (label.toLowerCase().trim()) {
      case 'all status':
      case 'status':
      case 'all':
        return allId;
      case 'present today':
      case 'present':
        return 'present';
      case 'active / working':
      case 'active':
      case 'working':
        return 'working';
      case 'on break':
      case 'break':
        return 'break';
      case 'late check-in':
      case 'late':
        return 'late';
      case 'early check-out':
      case 'early checkout':
        return 'early_checkout';
      case 'absent':
        return 'absent';
      default:
        return allId;
    }
  }

  static StatusFilterOption? byId(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }
}

class StatusFilterSheet {
  StatusFilterSheet._();

  static Future<String?> show(
    BuildContext context, {
    String selectedId = StatusFilterOption.allId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusFilterSheetBody(initialSelectedId: selectedId),
    );
  }
}

class _StatusFilterSheetBody extends StatefulWidget {
  const _StatusFilterSheetBody({required this.initialSelectedId});

  final String initialSelectedId;

  @override
  State<_StatusFilterSheetBody> createState() => _StatusFilterSheetBodyState();
}

class _StatusFilterSheetBodyState extends State<_StatusFilterSheetBody> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.h5(
                      'Status',
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
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: StatusFilterOption.options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = StatusFilterOption.options[index];
                  final selected = option.id == _selectedId;
                  return _StatusOptionTile(
                    option: option,
                    selected: selected,
                    onTap: () => setState(() => _selectedId = option.id),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: kDividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: MyButton(         height: 45,
                      backgroundColor: kWhite,
                      outlineColor: kBorderColor,
                      fontColor: kBlack,
                      buttonText: 'Reset',
                      onTap: () async {
                        setState(
                          () => _selectedId = StatusFilterOption.allId,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: MyButton(
                      backgroundColor: kPrimaryButtonColor,
                      buttonText: 'Save',          height: 45,
                      onTap: () async {
                        Navigator.pop(context, _selectedId);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOptionTile extends StatelessWidget {
  const _StatusOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final StatusFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kPrimaryColor : kBorderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CommonImageView(imagePath: option.icon, height: 22),
            const SizedBox(width: 12),
            Expanded(
              child: AppText.p2(
                option.label,
                color: kBlack,
                weight: FontWeight.w500,
                align: TextAlign.left,
              ),
            ),
            _StatusRadio(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _StatusRadio extends StatelessWidget {
  const _StatusRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? kPrimaryColor : kGreyColor3,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
