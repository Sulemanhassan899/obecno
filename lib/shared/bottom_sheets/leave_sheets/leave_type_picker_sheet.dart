import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/employee_module/leaves/data/mock/leaves_mock_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/widgets/my_button.dart';

/// Leave options shown when tapping Leave type on Apply sheet.
class LeaveTypePickerSheet extends StatefulWidget {
  const LeaveTypePickerSheet({
    super.key,
    required this.selectedTypeId,
    required this.requestedDays,
  });

  final String? selectedTypeId;
  final int requestedDays;

  static const _pickerIds = [
    'casual',
    'sick',
    'misc',
    'paternity',
    'bereavement',
  ];

  static Future<LeaveTypeInfo?> show(
    BuildContext context, {
    String? selectedTypeId,
    int requestedDays = 1,
  }) {
    return AppSheet.show<LeaveTypeInfo>(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ConstrainedBox(
          constraints: AppSheetSize.constraintsOf(context),
          child: LeaveTypePickerSheet(
            selectedTypeId: selectedTypeId,
            requestedDays: requestedDays,
          ),
        );
      },
    );
  }

  @override
  State<LeaveTypePickerSheet> createState() => _LeaveTypePickerSheetState();
}

class _LeaveTypePickerSheetState extends State<LeaveTypePickerSheet> {
  late String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedTypeId;
  }

  String _label(LeaveTypeInfo type) {
    switch (type.id) {
      case 'casual':
        return 'Casual leave';
      case 'sick':
        return 'Sick leave';
      case 'misc':
        return 'Miscellaneous leave';
      case 'paternity':
        return 'Paternity leave';
      case 'bereavement':
        return 'Bereavement leave';
      default:
        return type.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = LeavesMockStore.instance;
    final types = [
      for (final id in LeaveTypePickerSheet._pickerIds)
        if (store.typeById(id) != null) store.typeById(id)!,
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              AppText.h5('Leave type', weight: FontWeight.w600),
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
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final type = types[index];
                final selected = type.id == _selectedId;
                final low = type.available <= 1;
                return ButtonAnimations.press(
                  onTap: () => setState(() => _selectedId = type.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? kPrimaryColor : kBorderColor,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText.p1(
                            _label(type),
                            weight: FontWeight.w400,
                            align: TextAlign.left,
                          ),
                        ),
                        AppText.p2(
                          LeaveFormat.availableLabel(type.available),
                          color: low ? kredColor : kBlue,
                          weight: FontWeight.w500,
                        ),
                        const SizedBox(width: 12),
                        _LeaveRadioDot(selected: selected),
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
              LeaveTypeInfo? type;
              for (final item in types) {
                if (item.id == _selectedId) {
                  type = item;
                  break;
                }
              }
              if (type == null) return;
              Navigator.pop(context, type);
            },
          ),
        ),
      ],
    );
  }
}

class _LeaveRadioDot extends StatelessWidget {
  const _LeaveRadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? kPrimaryColor : kBorderColor,
          width: 2,
        ),
        color: selected ? kPrimaryColor : kWhite,
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
