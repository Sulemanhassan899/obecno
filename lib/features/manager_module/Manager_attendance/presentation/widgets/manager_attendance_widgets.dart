import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/filter_dropdown_chip.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_status_filters_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/date_picker.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
import 'package:obecno/widgets/animated_searchbar.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/dot.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';

/// In-memory recent attendance search results (empty until first search).
class ManagerAttendanceRecentSearch {
  ManagerAttendanceRecentSearch._();

  static final List<ManagerAttendanceModel> items = [];

  static void add(ManagerAttendanceModel person) {
    items.removeWhere((e) => e.name == person.name);
    items.insert(0, person);
    if (items.length > 10) items.removeLast();
  }
}

/// =======================================================
/// HEADER
/// =======================================================
class ManagerAttendanceHeader extends StatefulWidget {
  const ManagerAttendanceHeader({
    super.key,
    this.selectedDate,
    this.onDateSelected,
    this.onSearchModeChanged,
    this.onSearchQueryChanged,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;
  final ValueChanged<bool>? onSearchModeChanged;
  final ValueChanged<String>? onSearchQueryChanged;

  @override
  State<ManagerAttendanceHeader> createState() =>
      _ManagerAttendanceHeaderState();
}

class _ManagerAttendanceHeaderState extends State<ManagerAttendanceHeader> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  static const _shortMonths = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final label = "${date.day} ${_shortMonths[date.month - 1]}";
    return isToday ? "Today - $label" : label;
  }

  void _onDateTap(BuildContext context) {
    final initial = widget.selectedDate ?? DateTime.now();
    DateMonthYearPickerSheet.show(
      context,
      initialDate: initial,
      onSelected: (date) => widget.onDateSelected?.call(date),
    );
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    widget.onSearchModeChanged?.call(true);
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() => _isSearching = false);
    widget.onSearchModeChanged?.call(false);
    widget.onSearchQueryChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.selectedDate ?? DateTime.now();
    final searchWidth = MediaQuery.sizeOf(context).width - 32;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: _isSearching
            ? AnimSearchBar(
                key: const ValueKey('attendance-search-open'),
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
                onChanged: (value) => widget.onSearchQueryChanged?.call(value),
                searchBarOpen: (value) {
                  if (value == 0) _closeSearch();
                },
              )
            : Row(
                children: [
                  ButtonAnimations.press(
                    onTap: () => _onDateTap(context),
                    child: Row(
                      children: [
                        CommonImageView(
                          imagePath: Assets.imagesCalender,
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 10),
                        AppText.h6(_formatDateLabel(date), color: kBlack),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ButtonAnimations.press(
                    onTap: _openSearch,
                    child: CommonImageView(
                      imagePath: Assets.imagesSearchButton,
                      height: 45,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ManagerFilters extends StatefulWidget {
  const ManagerFilters({
    super.key,
    this.initialStatus,
    this.initialLocationId,
    this.onStatusChanged,
    this.onLocationChanged,
    this.locations,
    this.useSingleLocationSheet = false,
  });

  /// Pre-selected status from Overview (label or id). Null = All Status.
  final String? initialStatus;
  final String? initialLocationId;
  final ValueChanged<String>? onStatusChanged;
  final ValueChanged<String>? onLocationChanged;

  /// Locations to show in the multi-location sheet.
  final List<LocationFilterOption>? locations;

  /// Force the single-location empty sheet.
  final bool useSingleLocationSheet;

  @override
  State<ManagerFilters> createState() => _ManagerFiltersState();
}

class _ManagerFiltersState extends State<ManagerFilters> {
  late String _selectedStatusId;
  late String _selectedLocationId;

  List<LocationFilterOption> get _locations {
    if (widget.locations != null) return widget.locations!;
    return context.watch<ManagerLocationsProvider>().filterOptions;
  }

  List<StatusFilterOption> get _statusOptions =>
      context.watch<ManagerStatusFiltersProvider>().options;

  bool get _hasStatusFilter =>
      _selectedStatusId != StatusFilterOption.allId &&
      _selectedStatusId.isNotEmpty;

  String get _statusChipLabel {
    if (!_hasStatusFilter) return 'Status';
    final fromStatic = StatusFilterOption.byId(_selectedStatusId)?.label;
    if (fromStatic != null && fromStatic.isNotEmpty) return fromStatic;
    final fromApi = StatusFilterOption.displayLabel(
      _selectedStatusId,
      _statusOptions,
    );
    if (fromApi.isNotEmpty && fromApi != 'Status') return fromApi;
    final initial = widget.initialStatus?.trim();
    if (initial != null &&
        initial.isNotEmpty &&
        initial.toLowerCase() != 'status' &&
        initial.toLowerCase() != 'all status') {
      return initial;
    }
    return 'Status';
  }

  bool get _hasLocationFilter =>
      _selectedLocationId != LocationFilterOption.allId;

  String get _locationChipLabel {
    if (!_hasLocationFilter) return 'Locations';
    for (final loc in _locations) {
      if (loc.id == _selectedLocationId) return loc.name;
    }
    return 'Locations';
  }

  @override
  void initState() {
    super.initState();
    _selectedStatusId = StatusFilterOption.idFromLabel(widget.initialStatus);
    _selectedLocationId =
        widget.initialLocationId ?? LocationFilterOption.allId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ManagerStatusFiltersProvider>().ensureLoaded();
      context.read<ManagerLocationsProvider>().load();
    });
  }

  @override
  void didUpdateWidget(covariant ManagerFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextStatus = StatusFilterOption.idFromLabel(widget.initialStatus);
    if (oldWidget.initialStatus != widget.initialStatus &&
        nextStatus != _selectedStatusId) {
      setState(() => _selectedStatusId = nextStatus);
    }
    if (oldWidget.initialLocationId != widget.initialLocationId &&
        widget.initialLocationId != null) {
      setState(() => _selectedLocationId = widget.initialLocationId!);
    }
  }

  Future<void> _openStatusSheet() async {
    final filtersProvider = context.read<ManagerStatusFiltersProvider>();
    await filtersProvider.ensureLoaded();
    if (!mounted) return;
    final result = await StatusFilterSheet.show(
      context,
      selectedId: StatusFilterOption.idFromLabel(
        _selectedStatusId,
        filtersProvider.options,
      ),
      options: filtersProvider.options,
    );
    if (result == null || !mounted) return;
    setState(() => _selectedStatusId = result);
    widget.onStatusChanged?.call(result);
  }

  Future<void> _openLocationSheet() async {
    final locations = widget.useSingleLocationSheet
        ? <LocationFilterOption>[]
        : _locations;

    final result = await LocationsFilterSheet.show(
      context,
      locations: locations,
      selectedId: _selectedLocationId,
    );
    if (result == null || !mounted) return;
    setState(() => _selectedLocationId = result);
    widget.onLocationChanged?.call(result);
  }

  void _clearStatus() {
    setState(() => _selectedStatusId = StatusFilterOption.allId);
    widget.onStatusChanged?.call(StatusFilterOption.allId);
  }

  void _clearLocation() {
    setState(() => _selectedLocationId = LocationFilterOption.allId);
    widget.onLocationChanged?.call(LocationFilterOption.allId);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _hasStatusFilter
              ? SelectedFilterChip(
                  label: _statusChipLabel,
                  onClear: _clearStatus,
                  onTap: _openStatusSheet,
                )
              : FilterChipButton(
                  label: _statusChipLabel,
                  onTap: _openStatusSheet,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _hasLocationFilter
              ? SelectedFilterChip(
                  label: _locationChipLabel,
                  onClear: _clearLocation,
                  onTap: _openLocationSheet,
                )
              : FilterChipButton(
                  label: _locationChipLabel,
                  onTap: _openLocationSheet,
                ),
        ),
      ],
    );
  }
}

class ManagerAttendanceTile extends StatelessWidget {
  final ManagerAttendanceModel data;
  final VoidCallback? onTap;

  const ManagerAttendanceTile({super.key, required this.data, this.onTap});

  /// ---------------- HELPERS ----------------

  bool get _hasCheckIn =>
      data.checkIn != null && data.checkIn!.trim().isNotEmpty;

  bool get _hasCheckOut =>
      data.checkOut != null && data.checkOut!.trim().isNotEmpty;

  bool get _hasRole => data.role != null && data.role!.trim().isNotEmpty;

  bool get _hasTeam => data.team != null && data.team!.trim().isNotEmpty;

  bool get _isRecognizedStatus {
    switch (data.status.toLowerCase().trim()) {
      case "working":
      case "active":
      case "break":
      case "onbreak":
      case "on break":
      case "late":
      case "leave":
      case "on leave":
        return true;
      default:
        return false;
    }
  }

  bool get _showEmptyState =>
      !_hasCheckIn && !_hasCheckOut && !_isRecognizedStatus;

  bool get _isLate => data.status.toLowerCase() == "late";

  bool get _isLeave {
    switch (data.status.toLowerCase().trim()) {
      case "leave":
      case "on leave":
        return true;
      default:
        return false;
    }
  }

  bool get _timesInRed => data.warningred || _isLate;

  String _statusText() {
    switch (data.status.toLowerCase().trim()) {
      case "working":
      case "active":
        return "Working";
      case "break":
      case "onbreak":
      case "on break":
        return "On Break";
      case "late":
        return "Late";
      case "leave":
      case "on leave":
        return "On Leave";
      default:
        return "";
    }
  }

  Color _statusBgColor() {
    switch (data.status.toLowerCase().trim()) {
      case "working":
      case "active":
        return const Color(0xFFE6F9ED);
      case "late":
        return const Color(0xFFFFEBEE);
      case "break":
      case "onbreak":
      case "on break":
        return const Color(0xFFFFF4E0);
      case "leave":
      case "on leave":
        return const Color(0xFFE8F1FF);
      default:
        return kgreenColorLight;
    }
  }

  Color _statusTextColor() {
    switch (data.status.toLowerCase().trim()) {
      case "working":
      case "active":
        return const Color(0xFF1FA855);
      case "late":
        return kredColor;
      case "break":
      case "onbreak":
      case "on break":
        return const Color(0xFFCC8B00);
      case "leave":
      case "on leave":
        return const Color(0xFF3B82F6);
      default:
        return kPrimaryColor;
    }
  }

  Color _roleBgColor() {
    switch (data.role?.toLowerCase()) {
      case "manager":
        return kPurple.withOpacity(0.15);
      case "owner":
      default:
        return kgreenColorLight;
    }
  }

  Color _roleTextColor() {
    switch (data.role?.toLowerCase()) {
      case "manager":
        return kPurple;
      case "owner":
      default:
        return const Color(0xFF1FA855);
    }
  }

  Widget? _alertIcon() {
    if (data.editIcon) {
      return CommonImageView(imagePath: Assets.imagesPen, height: 18);
    }
    if (data.warningred) {
      return CommonImageView(
        imagePath: Assets.imagesTriangleExclamation,
        height: 18,
      );
    }
    if (data.warning) {
      return CommonImageView(imagePath: Assets.imagesWarningAlert, height: 20);
    }
    if (data.locationalert) {
      return CommonImageView(imagePath: Assets.imagesLocationAlert, height: 20);
    }
    if (data.infoalert) {
      return CommonImageView(imagePath: Assets.imagesInfoAlert, height: 20);
    }
    return null;
  }

  Widget _statusBadge() {
    final text = _statusText();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBgColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText.caption(
        text,
        color: _statusTextColor(),
        weight: FontWeight.w500,
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kGreyColor.withOpacity(0.2),
      ),
      child: AppText.caption("-", color: kGreyColor, weight: FontWeight.w500),
    );
  }

  Widget _timeText(String value, {bool forceRed = false}) {
    return AppText.p2(
      value,
      color: (forceRed || _timesInRed) ? kredColor : kBlack,
      weight: FontWeight.w400,
    );
  }

  Widget _connector() =>
      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Dot());

  /// Right-side: times and/or status badge.
  /// Leave rows: `5 Days` / `09:05 AM` —●——●— `On Leave`
  Widget _trailing() {
    if (_showEmptyState) return _emptyState();

    final statusLabel = _statusText();
    final showBadgeInsteadOfCheckout = statusLabel.isNotEmpty && !_hasCheckOut;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasCheckIn) _timeText(data.checkIn!, forceRed: _isLate),
        // No connector on leave rows — just duration + "On Leave" badge.
        if (_hasCheckIn &&
            (_hasCheckOut || showBadgeInsteadOfCheckout) &&
            !_isLeave)
          _connector(),
        if (_isLeave && _hasCheckIn && showBadgeInsteadOfCheckout)
          const SizedBox(width: 10),
        if (_hasCheckOut)
          _timeText(data.checkOut!)
        else if (showBadgeInsteadOfCheckout)
          _statusBadge(),
      ],
    );
  }

  /// ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final icon = _alertIcon();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /// LEFT — name / role / team
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: (_hasRole || _hasTeam)
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    AppText.p2(
                      data.name,
                      color: kBlack,
                      weight: FontWeight.w500,
                      align: TextAlign.left,
                    ),
                    if (_hasRole || _hasTeam) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (_hasRole)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _roleBgColor(),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: AppText.caption(
                                data.role!,
                                color: _roleTextColor(),
                                weight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            /// CENTER — alert / edit icons
            if (icon != null) ...[
              const SizedBox(width: 8),
              icon,
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 12),

            /// RIGHT — times / status / empty dash
            _trailing(),
          ],
        ),
      ),
    );
  }
}

/// =======================================================
/// SEARCH RESULT TILE (avatar + name + role + status)
/// =======================================================
class ManagerSearchPersonTile extends StatelessWidget {
  const ManagerSearchPersonTile({super.key, required this.data, this.onTap});

  final ManagerAttendanceModel data;
  final VoidCallback? onTap;

  String _statusLabel() {
    switch (data.status.toLowerCase().trim()) {
      case "working":
      case "active":
        return "Working";
      case "break":
      case "on break":
      case "onbreak":
        return "On Break";
      case "leave":
      case "on leave":
      case "absent":
        return "On Leave";
      case "late":
        return "Late";
      default:
        return data.status.isEmpty ? "" : data.status;
    }
  }

  Color _badgeBg() {
    switch (data.status.toLowerCase().trim()) {
      case "working":
      case "active":
        return const Color(0xFFE6F9ED);
      case "break":
      case "on break":
      case "onbreak":
        return const Color(0xFFFFF4E0);
      case "leave":
      case "on leave":
      case "absent":
        return const Color(0xFFE8F1FF);
      case "late":
        return const Color(0xFFFFEBEE);
      default:
        return kGreyColor.withOpacity(0.12);
    }
  }

  Color _badgeFg() {
    switch (data.status.toLowerCase().trim()) {
      case "working":
      case "active":
        return const Color(0xFF1FA855);
      case "break":
      case "on break":
      case "onbreak":
        return const Color(0xFFCC8B00);
      case "leave":
      case "on leave":
      case "absent":
        return const Color(0xFF3B82F6);
      case "late":
        return kredColor;
      default:
        return kGreyColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel();

    return ButtonAnimations.press(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ClipOval(
              child: CommonImageView(
                imagePath: data.photo ?? Assets.imagesUserimage,
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
                    data.name,
                    color: kBlack,
                    weight: FontWeight.w600,
                    align: TextAlign.left,
                  ),
                  if (data.role != null && data.role!.trim().isNotEmpty) ...[
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
            if (status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _badgeBg(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText.caption(
                  status,
                  color: _badgeFg(),
                  weight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Search body: blank / recent / employees / no results
class ManagerAttendanceSearchView extends StatelessWidget {
  const ManagerAttendanceSearchView({
    super.key,
    required this.query,
    required this.results,
    required this.recent,
    this.onPersonTap,
  });

  final String query;
  final List<ManagerAttendanceModel> results;
  final List<ManagerAttendanceModel> recent;
  final ValueChanged<ManagerAttendanceModel>? onPersonTap;

  bool get _hasQuery => query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasQuery && recent.isEmpty) {
      return const SizedBox.expand();
    }

    if (!_hasQuery) {
      return _section(title: "Recent Search", people: recent);
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText.h4("No Results", weight: FontWeight.w700, color: kBlack),
              const SizedBox(height: 10),
              AppText.p2(
                'There were no results for “${query.trim()}”. Try new search',
                color: kGreyColor,
                weight: FontWeight.w400,
              ),
            ],
          ),
        ),
      );
    }

    return _section(title: "Employees", people: results);
  }

  Widget _section({
    required String title,
    required List<ManagerAttendanceModel> people,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.h6(title, color: kBlack, weight: FontWeight.w600),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: people.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: kDividerColor),
            itemBuilder: (context, index) {
              final person = people[index];
              return ManagerSearchPersonTile(
                data: person,
                onTap: () => onPersonTap?.call(person),
              );
            },
          ),
        ),
      ],
    );
  }
}
