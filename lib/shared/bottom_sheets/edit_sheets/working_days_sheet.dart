import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_policy_log.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class WorkingDaysSheet {
  WorkingDaysSheet._();

  static Future<LocationSchedule?> show(
    BuildContext context, {
    int? userId,
    String? employeeName,
    String? locationId,
    LocationSchedule? schedule,
  }) {
    return showModalBottomSheet<LocationSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkingDaysSheetBody(
        userId: userId,
        employeeName: employeeName,
        locationId: locationId,
        schedule: schedule,
      ),
    );
  }
}

class _WorkingDaysSheetBody extends StatefulWidget {
  const _WorkingDaysSheetBody({
    this.userId,
    this.employeeName,
    this.locationId,
    this.schedule,
  });

  final int? userId;
  final String? employeeName;
  final String? locationId;
  final LocationSchedule? schedule;

  @override
  State<_WorkingDaysSheetBody> createState() => _WorkingDaysSheetBodyState();
}

class _WorkingDaysSheetBodyState extends State<_WorkingDaysSheetBody> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late Set<String> _selectedDays;
  late Set<String> _initialDays;
  bool _workingWeekEnabled = true;
  bool _initialWorkingWeekEnabled = true;
  String _startDay = 'Monday';
  String _initialStartDay = 'Monday';
  String _hoursInWeek = '40:00';
  String _initialHoursInWeek = '40:00';
  String _hoursInDay = '08:00';
  String _initialHoursInDay = '08:00';
  bool _saving = false;
  bool _loading = false;
  LocationSchedule _baseSchedule = LocationSchedule.defaults;

  @override
  void initState() {
    super.initState();
    _applySchedule(widget.schedule ?? LocationSchedule.defaults);
    _load();
  }

  void _applySchedule(LocationSchedule schedule) {
    _baseSchedule = schedule;
    _selectedDays = Set<String>.from(schedule.workingDays);
    _initialDays = Set.from(_selectedDays);
    _workingWeekEnabled = schedule.workingWeekEnabled;
    _initialWorkingWeekEnabled = schedule.workingWeekEnabled;
    _startDay = schedule.weekStartDay;
    _initialStartDay = schedule.weekStartDay;
    _hoursInWeek = schedule.hoursPerWeek;
    _initialHoursInWeek = schedule.hoursPerWeek;
    _hoursInDay = schedule.hoursPerDay;
    _initialHoursInDay = schedule.hoursPerDay;
  }

  Future<void> _load() async {
    final locationId = widget.locationId?.trim();
    if (locationId != null && locationId.isNotEmpty) {
      setState(() => _loading = true);
      final result = await bindings.managerLocationsService.loadLocationSchedule(
        locationId: locationId,
      );
      if (!mounted) return;
      setState(() {
        if (result.success && result.data != null) {
          _applySchedule(result.data!);
        }
        _loading = false;
      });
      LocationPolicyLog.dump(
        sheet: 'working_days',
        phase: 'fetched',
        locationId: locationId,
        schedule: result.data ?? _baseSchedule,
        success: result.success,
        statusCode: result.statusCode,
        message: result.message,
      );
      return;
    }

    final userId = widget.userId;
    if (userId == null) return;
    setState(() => _loading = true);
    final result = await bindings.managerEmployeesService.loadEmployeeSchedule(
      userId: userId,
    );
    if (!mounted) return;
    setState(() {
      if (result.success && result.data != null) {
        _applySchedule(result.data!);
      }
      _loading = false;
    });
  }

  void _reset() {
    setState(() {
      _selectedDays = Set.from(_initialDays);
      _workingWeekEnabled = _initialWorkingWeekEnabled;
      _startDay = _initialStartDay;
      _hoursInWeek = _initialHoursInWeek;
      _hoursInDay = _initialHoursInDay;
    });
  }

  LocationSchedule get _currentSchedule {
    return _baseSchedule.copyWith(
      workingDays: Set<String>.from(_selectedDays),
      weekStartDay: _startDay,
      hoursPerDay: _hoursInDay,
      hoursPerWeek: _hoursInWeek,
      workingWeekEnabled: _workingWeekEnabled,
    );
  }

  bool _sameDays(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    final normalized = b.map((day) => day.trim().toLowerCase()).toSet();
    for (final day in a) {
      if (!normalized.contains(day.trim().toLowerCase())) return false;
    }
    return true;
  }

  Future<void> _save() async {
    final locationId = widget.locationId?.trim();
    if (locationId != null && locationId.isNotEmpty) {
      setState(() => _saving = true);
      final current = _baseSchedule;
      final next = _currentSchedule;
      LocationPolicyLog.dump(
        sheet: 'working_days',
        phase: 'current',
        locationId: locationId,
        schedule: current,
      );
      LocationPolicyLog.dump(
        sheet: 'working_days',
        phase: 'changed',
        locationId: locationId,
        schedule: next,
      );
      final result = await bindings.managerLocationsService
          .updateLocationSchedule(locationId: locationId, schedule: next);
      if (!mounted) return;
      setState(() => _saving = false);
      LocationPolicyLog.dump(
        sheet: 'working_days',
        phase: 'response',
        locationId: locationId,
        schedule: result.data ?? next,
        success: result.success,
        statusCode: result.statusCode,
        message: result.message,
      );
      if (!result.success) {
        ToastHelper.error(
          context,
          message: result.message ?? 'Failed to save working days.',
        );
        return;
      }
      final saved = result.data ?? next;
      _applySchedule(saved);
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      Navigator.pop(context, saved);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!rootContext.mounted) return;
        ToastHelper.changesSaved(rootContext);
      });
      return;
    }

    if (widget.userId != null) {
      if (_selectedDays.isEmpty) {
        ToastHelper.error(
          context,
          message: 'Select at least one working day.',
        );
        return;
      }
      setState(() => _saving = true);
      final next = _currentSchedule;
      final result = await bindings.managerEmployeesService
          .updateEmployeeSchedule(
            userId: widget.userId!,
            payload: {
              ...ManagerEmployeePolicy.workingDaysPermissionPayload(
                workingDays: _selectedDays,
                weekStartDay: _startDay,
                hoursPerDay: _hoursInDay,
                hoursPerWeek: _hoursInWeek,
                workingWeekEnabled: _workingWeekEnabled,
              ),
              ...next.writePayload(),
            },
          );
      if (!mounted) return;
      if (!result.success) {
        setState(() => _saving = false);
        ToastHelper.error(
          context,
          message: result.message ?? 'Failed to save working days.',
        );
        return;
      }

      final verify = await bindings.managerEmployeesService
          .loadEmployeeSchedule(userId: widget.userId!);
      if (!mounted) return;
      setState(() => _saving = false);
      if (!verify.success || verify.data == null) {
        ToastHelper.error(
          context,
          message:
              verify.message ?? 'Working days update could not be confirmed.',
        );
        return;
      }
      final saved = verify.data!;
      if (!_sameDays(saved.workingDays, _selectedDays) ||
          saved.weekStartDay.trim().toLowerCase() !=
              _startDay.trim().toLowerCase() ||
          saved.workingWeekEnabled != _workingWeekEnabled) {
        ToastHelper.error(
          context,
          message: 'Working days did not persist. Please try again.',
        );
        return;
      }
      _applySchedule(saved);
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      Navigator.pop(context, saved);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!rootContext.mounted) return;
        ToastHelper.changesSaved(rootContext);
      });
      return;
    }

    _initialDays = Set.from(_selectedDays);
    _initialWorkingWeekEnabled = _workingWeekEnabled;
    _initialStartDay = _startDay;
    _initialHoursInWeek = _hoursInWeek;
    _initialHoursInDay = _hoursInDay;

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context, _currentSchedule);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      ToastHelper.changesSaved(rootContext);
    });
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText.h5(
                          title,
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                      ),
                      ButtonAnimations.press(
                        onTap: () => Navigator.pop(sheetContext),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.close, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: kDividerColor),
                ...options.map(
                  (option) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(sheetContext, option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText.p2(
                              option,
                              align: TextAlign.left,
                              weight: FontWeight.w500,
                            ),
                          ),
                          if (option == current)
                            const Icon(
                              Icons.check,
                              color: kPrimaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
    if (result != null && mounted) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.9,
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.h5(
                      'Working Days',
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
            Expanded(
              child: Container(
                color: kbackground2,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  children: [
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppText.p1(
                        widget.employeeName != null &&
                                widget.employeeName!.trim().isNotEmpty
                            ? 'Set working days for ${widget.employeeName!.trim()}.'
                            : 'Set working days for this ${widget.userId != null ? 'employee' : 'location'}.',
                        color: kGreyColor,
                        align: TextAlign.left,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _days.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 1, color: kDividerColor),
                            _DayTile(
                              label: _days[i],
                              selected: _selectedDays.contains(_days[i]),
                              onTap: () {
                                setState(() {
                                  if (_selectedDays.contains(_days[i])) {
                                    _selectedDays.remove(_days[i]);
                                  } else {
                                    _selectedDays.add(_days[i]);
                                  }
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppText.h5('Working Week', align: TextAlign.left),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ToggleRow(
                            label: 'Working Days',
                            value: _workingWeekEnabled,
                            onChanged: (v) =>
                                setState(() => _workingWeekEnabled = v),
                          ),
                          const Divider(height: 1, color: kDividerColor),
                          _DropdownRow(
                            label: 'Workweek Start Day',
                            value: _startDay,
                            onTap: () => _pickOption(
                              title: 'Workweek Start Day',
                              options: _days,
                              current: _startDay,
                              onSelected: (v) => setState(() => _startDay = v),
                            ),
                          ),
                          const Divider(height: 1, color: kDividerColor),
                          _DropdownRow(
                            label: 'Hours in a Week',
                            value: _hoursInWeek,
                            onTap: () => _pickOption(
                              title: 'Hours in a Week',
                              options: const [
                                '35:00',
                                '37:30',
                                '40:00',
                                '45:00',
                              ],
                              current: _hoursInWeek,
                              onSelected: (v) =>
                                  setState(() => _hoursInWeek = v),
                            ),
                          ),
                          const Divider(height: 1, color: kDividerColor),
                          _DropdownRow(
                            label: 'Hours in a Day',
                            value: _hoursInDay,
                            onTap: () => _pickOption(
                              title: 'Hours in a Day',
                              options: const [
                                '07:00',
                                '07:30',
                                '08:00',
                                '09:00',
                              ],
                              current: _hoursInDay,
                              onSelected: (v) =>
                                  setState(() => _hoursInDay = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppText.p1(
                      "When enabled, this location's working week will overwrite the global working week.",
                      color: kGreyColor,
                      weight: FontWeight.w400,
                      align: TextAlign.left,
                    ),
                  ],
                ),
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
                      buttonText: 'Reset',
                      backgroundColor: kWhite,
                      fontColor: kBlack,
                      outlineColor: kBorderColor,
                      onTap: () async => _reset(),
                    ),
                  ),
                  const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: MyButton(
                        buttonText: 'Save',
                        backgroundColor: kPrimaryButtonColor,
                        isactive: !_saving && !_loading,
                        isLoadingExternally: _saving,
                        onTap: _save,
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

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: AppText.p2(
                label,
                color: kBlack,
                weight: FontWeight.w500,
                align: TextAlign.left,
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: kPrimaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: AppText.p2(
              label,
              color: kBlack,
              weight: FontWeight.w500,
              align: TextAlign.left,
            ),
          ),
          SizedBox(
            width: 55,
            height: 40,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch.adaptive(
                value: value,
                activeColor: kPrimaryColor,
                thumbColor: MaterialStateProperty.all(kWhite),
                trackColor: MaterialStateProperty.all(kPrimaryColor),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: AppText.p2(
                label,
                color: kBlack,
                weight: FontWeight.w500,
                align: TextAlign.left,
              ),
            ),
            AppText.p2(value, color: kGreyColor, weight: FontWeight.w500),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: kGreyColor),
          ],
        ),
      ),
    );
  }
}
