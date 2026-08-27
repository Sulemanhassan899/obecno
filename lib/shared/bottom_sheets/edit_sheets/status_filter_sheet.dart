import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
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
    StatusFilterOption(id: 'absent', label: 'Absent', icon: Assets.AbsentIcon),
  ];

  static String _norm(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'[\s\-_\/]+'), '');

  static const _families = <Set<String>>[
    {'all', 'allstatus', 'status'},
    {'present', 'presenttoday'},
    {'working', 'active', 'activeworking', 'inprogress'},
    {'break', 'onbreak'},
    {'late', 'latecheckin'},
    {'earlycheckout', 'early'},
    {'leave', 'onleave', 'onleaves', 'leaves'},
    {'absent'},
  ];

  static bool sameFamily(String a, String b) {
    final left = _norm(a);
    final right = _norm(b);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;
    for (final family in _families) {
      if (family.contains(left) && family.contains(right)) return true;
    }
    return false;
  }

  /// Radio selection must be exact. API lists can include both `late` and
  /// `late_check_in`, which share a filter family but are separate rows.
  static bool isSelected(String optionId, String selectedId) {
    return optionId.trim().toLowerCase() == selectedId.trim().toLowerCase();
  }

  /// Maps overview / legacy labels → status option id.
  static String idFromLabel(
    String? label, [
    List<StatusFilterOption>? options,
  ]) {
    if (label == null || label.trim().isEmpty) return allId;
    final normalized = label.toLowerCase().trim();
    final list = options ?? StatusFilterOption.options;

    // Location overview uses "On Leaves"; not always present in API options.
    if (sameFamily(normalized, 'leave')) return 'leave';

    String? matchIn(List<StatusFilterOption> source, {required bool exact}) {
      for (final option in source) {
        if (exact) {
          if (option.id.toLowerCase() == normalized ||
              option.label.toLowerCase() == normalized) {
            return option.id;
          }
        } else if (sameFamily(option.id, label) ||
            sameFamily(option.label, label)) {
          return option.id;
        }
      }
      return null;
    }

    return matchIn(list, exact: true) ??
        matchIn(list, exact: false) ??
        matchIn(StatusFilterOption.options, exact: true) ??
        matchIn(StatusFilterOption.options, exact: false) ??
        allId;
  }

  static StatusFilterOption? byId(
    String id, [
    List<StatusFilterOption>? options,
  ]) {
    final list = options ?? StatusFilterOption.options;
    for (final option in list) {
      if (option.id == id) return option;
    }
    for (final option in list) {
      if (sameFamily(option.id, id) || sameFamily(option.label, id)) {
        return option;
      }
    }
    return null;
  }

  static String displayLabel(
    String? idOrLabel, [
    List<StatusFilterOption>? options,
  ]) {
    if (idOrLabel == null || idOrLabel.trim().isEmpty) return 'Status';
    final resolved = idFromLabel(idOrLabel, options);
    if (resolved == allId) {
      return byId(idOrLabel)?.label ?? 'Status';
    }
    return byId(resolved, options)?.label ??
        byId(resolved)?.label ??
        idOrLabel;
  }
}

class StatusFilterSheet {
  StatusFilterSheet._();

  static Future<String?> show(
    BuildContext context, {
    String selectedId = StatusFilterOption.allId,
    List<StatusFilterOption>? options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusFilterSheetBody(
        initialSelectedId: selectedId,
        options: options,
      ),
    );
  }
}

class _StatusFilterSheetBody extends StatefulWidget {
  const _StatusFilterSheetBody({required this.initialSelectedId, this.options});

  final String initialSelectedId;
  final List<StatusFilterOption>? options;

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

  List<StatusFilterOption> get _options =>
      (widget.options != null && widget.options!.isNotEmpty)
      ? widget.options!
      : StatusFilterOption.options;

  @override
  Widget build(BuildContext context) {
    final options = _options;

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
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = StatusFilterOption.isSelected(
                    option.id,
                    _selectedId,
                  );
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
                    child: MyButton(
                      size: MyButtonSize.normal,
                      backgroundColor: kWhite,
                      outlineColor: kBorderColor,
                      fontColor: kBlack,
                      buttonText: 'Reset',
                      onTap: () async {
                        setState(() => _selectedId = StatusFilterOption.allId);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: MyButton(
                      backgroundColor: kPrimaryButtonColor,
                      buttonText: 'Save',
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
