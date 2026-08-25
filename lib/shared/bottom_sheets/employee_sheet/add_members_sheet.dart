import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/demo/manager_employee_model.dart';
import 'package:obecno/demo/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/location_setup_screen.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class AddMembersSheet {
  AddMembersSheet._();

  static Future<void> show(
    BuildContext context, {
    required ManagerLocationModel location,
    String title = 'Add Member',
    bool openSetupOnAdd = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMembersSheetBody(
        location: location,
        title: title,
        openSetupOnAdd: openSetupOnAdd,
      ),
    );
  }
}

class _AddMembersSheetBody extends StatefulWidget {
  const _AddMembersSheetBody({
    required this.location,
    required this.title,
    required this.openSetupOnAdd,
  });

  final ManagerLocationModel location;
  final String title;
  final bool openSetupOnAdd;

  @override
  State<_AddMembersSheetBody> createState() => _AddMembersSheetBodyState();
}

class _AddMembersSheetBodyState extends State<_AddMembersSheetBody> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagerEmployeeModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return dummyManagerEmployees;
    return dummyManagerEmployees
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.role.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _onAdd() async {
    if (!widget.openSetupOnAdd) {
      Navigator.pop(context);
      return;
    }

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      Navigator.push(
        rootContext,
        MaterialPageRoute(
          builder: (_) => LocationSetupScreen(location: widget.location),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final people = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText.h5(
                        widget.title,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: CustomTextField(
                  controller: _searchController,
                  hintText: 'Search',
                  radius: 25,
                  hintTextFontColor: kBlack,
                  hintTextFontSize: 15,
                  preffixWidget: CommonImageView(
                    imagePath: Assets.Search,
                    height: 16,
                  ),
                  havePrefixIcon: true,

                  onChanged: (v) => setState(() => _query = v),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppText.h6(
                    'Employees',
                    weight: FontWeight.w600,
                    align: TextAlign.left,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: people.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: kDividerColor),
                  itemBuilder: (context, index) {
                    final person = people[index];
                    final selected = _selectedIds.contains(person.id);
                    return _MemberTile(
                      person: person,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedIds.remove(person.id);
                          } else {
                            _selectedIds.add(person.id);
                          }
                        });
                      },
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
                        buttonText: 'Clear',
                        backgroundColor: kWhite,
                        fontColor: kBlack,
                        outlineColor: kBorderColor,
                        onTap: () async {
                          setState(() => _selectedIds.clear());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: MyButton(
                        buttonText: 'Add',
                        backgroundColor: kPrimaryButtonColor,
                        onTap: _onAdd,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final ManagerEmployeeModel person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: CommonImageView(
                imagePath: person.photoPath,
                height: 44,
                width: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.p2(
                    person.name,
                    color: kBlack,
                    weight: FontWeight.w600,
                    align: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    spacing: 4,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (person.badgeLabel != null) ...[
                        _RoleBadge(label: person.badgeLabel!),
                      ],
                      AppText.caption(
                        person.role,
                        color: kGreyColor,
                        align: TextAlign.left,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _CheckBox(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isManager = label.toLowerCase() == 'manager';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isManager
            ? const Color(0xFFEDE7FF)
            : kPrimaryColor2.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText.caption(
        label,
        color: isManager ? kPurple : kPrimaryColor,
        weight: FontWeight.w600,
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      width: 22,
      decoration: BoxDecoration(
        color: selected ? kPrimaryColor : kWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? kPrimaryColor : kGreyColor3,
          width: 1.5,
        ),
      ),
      child: selected ? const Icon(Icons.check, size: 14, color: kWhite) : null,
    );
  }
}
