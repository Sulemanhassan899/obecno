import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/demo/demo_list.dart';
import 'package:Obecno/demo/manager_attendence_model.dart';
import 'package:Obecno/features/manager_module/Manager_attendance/domain/manager_attendance_filters.dart';
import 'package:Obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';
import 'package:Obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  const ManagerAttendanceScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  late List<ManagerAttendanceModel> _filteredList;
  late String selectedStatus;
  String selectedLocation = "All Locations";
  DateTime _selectedDate = DateTime.now();

  bool _isSearching = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    selectedStatus = _normalizeStatusLabel(widget.initialStatus);
    _filteredList = _filterList();
  }

  @override
  void didUpdateWidget(covariant ManagerAttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      selectedStatus = _normalizeStatusLabel(widget.initialStatus);
      _applyFilters();
    }
  }

  String _normalizeStatusLabel(String? value) {
    final id = StatusFilterOption.idFromLabel(value);
    return StatusFilterOption.byId(id)?.label ?? 'All Status';
  }

  /// Unique people for search (by name).
  List<ManagerAttendanceModel> get _searchDirectory {
    final seen = <String>{};
    final list = <ManagerAttendanceModel>[];
    for (final item in dummyManagerAttendance) {
      final key = item.name.toLowerCase();
      if (seen.add(key)) list.add(item);
    }
    return list;
  }

  List<ManagerAttendanceModel> get _searchResults {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _searchDirectory
        .where((e) => e.name.toLowerCase().contains(q))
        .toList();
  }

  /// Maps raw model status → filter label used by the Status sheet.
  static String statusDisplayLabel(String raw) =>
      ManagerAttendanceFilters.statusDisplayLabel(raw);

  bool get _isAllStatus =>
      selectedStatus == 'All Status' || selectedStatus == 'Status';

  List<ManagerAttendanceModel> _filterList() {
    return ManagerAttendanceFilters.apply(
      source: dummyManagerAttendance,
      selectedStatus: selectedStatus,
      selectedLocation: selectedLocation,
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredList = _filterList();
    });
  }

  void _openDetails(ManagerAttendanceModel employee) {
    ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: _selectedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: ManagerAttendanceHeader(
                selectedDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() => _selectedDate = date);
                },
                onSearchModeChanged: (searching) {
                  setState(() {
                    _isSearching = searching;
                    if (!searching) _searchQuery = "";
                  });
                },
                onSearchQueryChanged: (query) {
                  setState(() => _searchQuery = query);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_isSearching)
              SliverFillRemaining(
                hasScrollBody: true,
                child: ManagerAttendanceSearchView(
                  query: _searchQuery,
                  results: _searchResults,
                  recent: ManagerAttendanceRecentSearch.items,
                  onPersonTap: (person) {
                    ManagerAttendanceRecentSearch.add(person);
                    _openDetails(person);
                  },
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: ManagerFilters(
                  initialStatus: _isAllStatus ? null : selectedStatus,
                  onStatusChanged: (value) {
                    selectedStatus = value;
                    _applyFilters();
                  },
                  onLocationChanged: (value) {
                    selectedLocation = value;
                    _applyFilters();
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverList.separated(
                itemCount: _filteredList.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 24, color: kDividerColor),
                itemBuilder: (context, index) {
                  final item = _filteredList[index];
                  return ManagerAttendanceTile(
                    data: item,
                    onTap: () => _openDetails(item),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}