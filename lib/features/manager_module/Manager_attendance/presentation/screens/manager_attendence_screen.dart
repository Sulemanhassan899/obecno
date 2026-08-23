import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_attendance_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  const ManagerAttendanceScreen({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  bool _isSearching = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ManagerAttendanceProvider>().ensureLoaded();
      context.read<ManagerLocationsProvider>().load();
    });
  }

  List<ManagerAttendanceModel> get _searchResults {
    return context.read<ManagerAttendanceProvider>().searchResults(
      _searchQuery,
    );
  }

  void _openDetails(ManagerAttendanceModel employee, DateTime day) {
    ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: day,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerAttendanceProvider>();
    final tiles = provider.tiles;
    final isInitialLoad = provider.isLoading && provider.items.isEmpty;

    return Scaffold(
      backgroundColor: kbackground1,
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: Padding(
          padding: AppSizes.DEFAULT,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: ManagerAttendanceHeader(
                  selectedDate: provider.selectedDate,
                  onDateSelected: provider.setDate,
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
                      _openDetails(person, provider.selectedDate);
                    },
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: ManagerFilters(
                    initialStatus: !provider.isAllStatus
                        ? provider.statusFilterId
                        : widget.initialStatus,
                    initialLocationId: provider.locationId,
                    onStatusChanged: provider.setStatus,
                    onLocationChanged: (id) {
                      final name = id == LocationFilterOption.allId
                          ? null
                          : context
                                .read<ManagerLocationsProvider>()
                                .byId(id)
                                ?.name;
                      provider.setLocation(id: id, name: name);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (isInitialLoad)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.hasError && provider.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _AttendanceMessage(
                      message:
                          provider.errorMessage ?? 'Failed to load attendance.',
                      actionLabel: 'Retry',
                      onAction: provider.load,
                    ),
                  )
                else if (tiles.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _AttendanceMessage(message: 'No attendance'),
                  )
                else
                  SliverList.separated(
                    itemCount: tiles.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 24, color: kDividerColor),
                    itemBuilder: (context, index) {
                      final item = tiles[index];
                      return ManagerAttendanceTile(
                        data: item,
                        onTap: () => _openDetails(item, provider.selectedDate),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceMessage extends StatelessWidget {
  const _AttendanceMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText.p1(message, color: kSubText, align: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
