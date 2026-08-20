import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/demo/manager_employee_model.dart';
import 'package:obecno/demo/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/filter_dropdown_chip.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_filters.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/add_employee_sheet.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/invite_sent_dialog.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_employee_profile_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/widgets/animated_searchbar.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class AllEmployeesScreen extends StatefulWidget {
  const AllEmployeesScreen({super.key, this.locationId});

  final String? locationId;

  @override
  State<AllEmployeesScreen> createState() => _AllEmployeesScreenState();
}

class _AllEmployeesScreenState extends State<AllEmployeesScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _query = '';
  late String _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _selectedLocationId = widget.locationId ?? LocationFilterOption.allId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagerEmployeeModel> get _locationEmployees {
    return ManagerEmployeeFilters.byLocation(
      source: dummyManagerEmployees,
      selectedLocationId: _selectedLocationId,
    );
  }

  List<ManagerEmployeeModel> get _filtered {
    return ManagerEmployeeFilters.byQuery(
      source: _locationEmployees,
      query: _query,
    );
  }

  int get _total => _locationEmployees.length;
  int get _active => _locationEmployees
      .where((e) => e.status == ManagerEmployeeStatus.active)
      .length;
  int get _pending => _locationEmployees
      .where((e) => e.status == ManagerEmployeeStatus.pending)
      .length;
  int get _disabled => _locationEmployees
      .where((e) => e.status == ManagerEmployeeStatus.disabled)
      .length;

  String get _locationChipLabel {
    if (_selectedLocationId == LocationFilterOption.allId) {
      return 'Locations';
    }
    final match =
        dummyManagerLocations.where((e) => e.id == _selectedLocationId);
    if (match.isEmpty) return 'Locations';
    return match.first.name;
  }

  Future<void> _openLocationFilter() async {
    final selected = await LocationsFilterSheet.show(
      context,
      locations: LocationFilterOption.demoMulti(),
      selectedId: _selectedLocationId,
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedLocationId = selected);
  }

  void _openProfile(ManagerEmployeeModel employee) {
    ManagerEmployeeProfileSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData(
        day: DateTime.now(),
        name: employee.name,
        role: employee.role,
        photo: employee.photo,
      ),
    );
  }

  void _openSearch() => setState(() => _isSearching = true);

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees = _filtered;
    final searchWidth = MediaQuery.sizeOf(context).width - 32;

    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: _isSearching
                          ? AnimSearchBar(
                              key: const ValueKey('employees-search-open'),
                              width: searchWidth,
                              rtl: true,
                              autoOpen: true,
                              autoFocus: true,
                              closeOnSubmit: false,
                              closeSearchOnSuffixTap: true,
                              boxShadow: true,
                              animationDurationInMilli: 500,
                              textFieldColor: kWhite,
                              searchIconColor: kBlack,
                              textFieldIconColor: kBlack,
                              textController: _searchController,
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(
                                color: kBlack,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: const Icon(Icons.close, size: 18),
                              onSuffixTap: () {},
                              onSubmitted: (_) {},
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              searchBarOpen: (value) {
                                if (value == 0) _closeSearch();
                              },
                            )
                          : BackButtonBg(
                              title: 'Employees',
                              padding: EdgeInsets.zero,
                              rightWidget: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ButtonAnimations.press(
                                    onTap: _openSearch,
                                    child: CommonImageView(
                                      imagePath: Assets.imagesSearchButton,
                                      height: 45,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ManagerPlusButton(
                                    onTap: () =>
                                        AddEmployeeSheet.show(context),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _EmployeeStatsBar(
                      total: _total,
                      active: _active,
                      pending: _pending,
                      disabled: _disabled,
                    ),
                    const SizedBox(height: 12),
                    if (_selectedLocationId == LocationFilterOption.allId)
                      FilterChipButton(
                        label: _locationChipLabel,
                        onTap: _openLocationFilter,
                      )
                    else
                      SelectedFilterChip(
                        label: _locationChipLabel,
                        onTap: _openLocationFilter,
                        onClear: () => setState(
                          () =>
                              _selectedLocationId = LocationFilterOption.allId,
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList.separated(
                itemCount: employees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _EmployeeCard(
                    employee: employees[index],
                    onTap: () => _openProfile(employees[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeStatsBar extends StatelessWidget {
  const _EmployeeStatsBar({
    required this.total,
    required this.active,
    required this.pending,
    required this.disabled,
  });

  final int total;
  final int active;
  final int pending;
  final int disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          _stat('$total', 'Total', kPrimaryColor),
          _divider(),
          _stat('$active', 'Active', kBlue),
          _divider(),
          _stat(pending.toString().padLeft(2, '0'), 'Pending', kGreyColor),
          _divider(),
          _stat('$disabled', 'Disabled', kOrangeColor),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: 28,
          child: VerticalDivider(width: 3, color: kDividerColor),
        ),
      );

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          AppText.h3(value, color: color,),
          const SizedBox(height: 2),
          AppText.caption(label, color: kGreyColor, weight: FontWeight.w500),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.onTap,
  });

  final ManagerEmployeeModel employee;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (employee.status) {
      case ManagerEmployeeStatus.pending:
        return kGreyColor;
      case ManagerEmployeeStatus.disabled:
        return kYellowColor;
      case ManagerEmployeeStatus.deleted:
        return kredColor;
      case ManagerEmployeeStatus.active:
        return kPrimaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            ClipOval(
              child: CommonImageView(
                imagePath: employee.photoPath,
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
                          employee.name,
                          color: kBlack,
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (employee.badgeLabel != null) ...[
                        const SizedBox(width: 8),
                        _Badge(label: employee.badgeLabel!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  AppText.caption(
                    employee.role,
                    color: kGreyColor,
                    weight: FontWeight.w400,
                    align: TextAlign.left,
                  ),
                ],
              ),
            ),
            if (employee.statusLabel != null) ...[
              Icon(Icons.circle, size: 12, color: _statusColor),
              const SizedBox(width: 6),
              AppText.caption(
                employee.statusLabel!,
                color: _statusColor,
                weight: FontWeight.w500,
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: kGreyColor, size: 22),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isManager = label.toLowerCase() == 'manager';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isManager ? const Color(0xFFEDE7FF) : kPrimaryColor2.withOpacity(0.5),
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
