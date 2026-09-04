import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_policy_log.dart';
import 'package:obecno/features/manager_module/Manager_locations/presentation/screens/location_overview_screen.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class AddMembersSheet {
  AddMembersSheet._();

  static Future<bool?> show(
    BuildContext context, {
    required ManagerLocationModel location,
    String title = 'Add Member',
    bool openSetupOnAdd = true,
  }) {
    return showModalBottomSheet<bool>(
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
  List<ManagerEmployeeModel> _employees = const [];
  String _query = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await bindings.managerEmployeesService.loadTeamMembers();
    if (!mounted) return;
    if (!result.success || result.data == null) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Failed to load employees.';
        _employees = const [];
      });
      return;
    }

    final people = result.data!.members
        .where((e) => e.status != ManagerEmployeeStatus.deleted)
        .toList(growable: false);
    final assigned = <String>{};
    for (final person in people) {
      if (person.assignedToLocation(
        id: widget.location.id,
        name: widget.location.name,
      )) {
        assigned.add(person.id);
      }
    }

    setState(() {
      _employees = people;
      _selectedIds
        ..clear()
        ..addAll(assigned);
      _loading = false;
    });
    LocationPolicyLog.dump(
      sheet: 'add_members',
      phase: 'fetched',
      locationId: widget.location.id,
      success: true,
      extra: {
        'employees': people.map((e) => e.id).join(','),
        'alreadyAssigned': assigned.join(','),
      },
    );
  }

  List<ManagerEmployeeModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _employees;
    return _employees
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.role.toLowerCase().contains(q) ||
              (e.email ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _onAdd() async {
    if (_selectedIds.isEmpty) {
      ToastHelper.error(context, message: 'Select employees to add.');
      return;
    }

    setState(() => _saving = true);
    LocationPolicyLog.dump(
      sheet: 'add_members',
      phase: 'current',
      locationId: widget.location.id,
      extra: {
        'alreadyAssigned': _employees
            .where(
              (e) => e.assignedToLocation(
                id: widget.location.id,
                name: widget.location.name,
              ),
            )
            .map((e) => e.id)
            .join(','),
      },
    );
    LocationPolicyLog.dump(
      sheet: 'add_members',
      phase: 'changed',
      locationId: widget.location.id,
      extra: {'selectedIds': _selectedIds.join(',')},
    );
    final result = await bindings.managerLocationsService.addLocationMembers(
      locationId: widget.location.id,
      employeeIds: _selectedIds.toList(),
    );
    if (!mounted) return;

    if (result.success) {
      await _syncEmployeeLocationAssignments();
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.success) {
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to assign employees.',
      );
      return;
    }

    if (!widget.openSetupOnAdd) {
      Navigator.pop(context, true);
      return;
    }

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context, true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      Navigator.push(
        rootContext,
        MaterialPageRoute(
          builder: (_) => LocationOverviewScreen(location: widget.location),
        ),
      );
    });
  }

  Future<void> _syncEmployeeLocationAssignments() async {
    for (final person in _employees) {
      if (!_selectedIds.contains(person.id)) continue;
      final userId = person.userId;
      if (userId == null) {
        LocationPolicyLog.dump(
          sheet: 'add_members',
          phase: 'response',
          locationId: widget.location.id,
          success: false,
          message: 'Skipped location write: missing user id',
          extra: {'employeeId': person.id},
        );
        continue;
      }

      final ids = <String>{
        ...person.locationIds,
        if ((person.locationId ?? '').trim().isNotEmpty) person.locationId!,
        widget.location.id,
      }.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
      final existingDefault = person.locationId?.trim();
      final defaultId =
          (existingDefault != null && existingDefault.isNotEmpty)
          ? existingDefault
          : widget.location.id;

      final write = await bindings.managerEmployeesService
          .updateEmployeeLocations(
            userId: userId,
            defaultLocationId: defaultId,
            locationIds: ids,
          );
      LocationPolicyLog.dump(
        sheet: 'add_members',
        phase: 'response',
        locationId: widget.location.id,
        success: write.success,
        statusCode: write.statusCode,
        message: write.message,
        extra: {
          'employeeId': person.id,
          'userId': userId,
          'locationIds': ids.join(','),
          'defaultLocationId': defaultId,
        },
      );
      if (!write.success) continue;
      bindings.managerEmployeesProvider.applyEmployeeLocations(
        userId: userId,
        defaultLocationId: defaultId,
        locationIds: ids,
        locationName: widget.location.name,
      );
    }
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
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
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
                      onTap: () => Navigator.pop(context, false),
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
              Expanded(child: _buildList(people)),
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
                        isactive: !_saving,
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
                        isactive: !_loading && !_saving,
                        isLoadingExternally: _saving,
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

  Widget _buildList(List<ManagerEmployeeModel> people) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText.p1(_error!, color: kSubText, align: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (people.isEmpty) {
      return Center(
        child: AppText.p1(
          _query.trim().isEmpty
              ? 'No employees found.'
              : 'No employees match your search.',
          color: kSubText,
          align: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipOval(
              child: CommonImageView(
                url: person.hasNetworkPhoto ? person.photo : null,
                imagePath: person.hasNetworkPhoto ? null : person.photoPath,
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
                  Row(
                    children: [
                      Flexible(
                        child: AppText.p2(
                          person.name,
                          color: kBlack,
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (person.badgeLabel != null) ...[
                        const SizedBox(width: 6),
                        _RoleBadge(label: person.badgeLabel!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  AppText.caption(
                    person.role,
                    color: kGreyColor,
                    align: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    final value = label.toLowerCase();
    final Color background;
    final Color foreground;
    if (value == 'manager') {
      background = const Color(0xFFEDE7FF);
      foreground = kPurple;
    } else if (value == 'you') {
      background = kPrimaryColor;
      foreground = kWhite;
    } else {
      background = kPrimaryColor2.withOpacity(0.5);
      foreground = kPrimaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText.caption(label, color: foreground, weight: FontWeight.w600),
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
