import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_policy_log.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:obecno/widgets/customswitch2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';

class BreakTimingSheet {
  BreakTimingSheet._();

  static Future<LocationSchedule?> show(
    BuildContext context, {
    int? userId,
    String? employeeName,
    String? locationId,
    LocationSchedule? schedule,
    String? maxBreak,
    bool? trackLocation,
  }) {
    LocationPolicyLog.dump(
      sheet: 'Break Timing',
      phase: 'open',
      locationId: locationId,
      api: userId != null
          ? 'PUT|PATCH /manager/employees/$userId/permissions'
          : (locationId == null || locationId.trim().isEmpty
              ? null
              : 'PUT /manager/locations/$locationId/schedule'),
      apiNeeds: 'max_break_minutes, break_location_tracking',
      extra: {'userId': userId, 'employeeName': employeeName},
    );
    return AppSheet.show<LocationSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BreakTimingSheetBody(
        userId: userId,
        employeeName: employeeName,
        locationId: locationId,
        schedule: schedule,
        maxBreak: maxBreak,
        trackLocation: trackLocation,
      ),
    );
  }
}

class _BreakTimingSheetBody extends StatefulWidget {
  const _BreakTimingSheetBody({
    this.userId,
    this.employeeName,
    this.locationId,
    this.schedule,
    this.maxBreak,
    this.trackLocation,
  });

  final int? userId;
  final String? employeeName;
  final String? locationId;
  final LocationSchedule? schedule;
  final String? maxBreak;
  final bool? trackLocation;

  @override
  State<_BreakTimingSheetBody> createState() => _BreakTimingSheetBodyState();
}

class _BreakTimingSheetBodyState extends State<_BreakTimingSheetBody> {
  String _maxBreak = '60:00 mins';
  String _initialMaxBreak = '60:00 mins';
  bool _trackLocation = true;
  bool _initialTrackLocation = true;
  bool _saving = false;
  bool _loading = false;
  LocationSchedule _baseSchedule = LocationSchedule.defaults;

  bool get _isEmployeeContext => widget.userId != null;

  static const _durationOptions = [
    '30:00 mins',
    '45:00 mins',
    '60:00 mins',
    '90:00 mins',
  ];

  @override
  void initState() {
    super.initState();
    final seeded = widget.schedule ?? LocationSchedule.defaults;
    _applySchedule(seeded);
    if (widget.maxBreak != null) _maxBreak = widget.maxBreak!;
    if (widget.trackLocation != null) _trackLocation = widget.trackLocation!;
    _initialMaxBreak = _maxBreak;
    _initialTrackLocation = _trackLocation;
    _load();
  }

  void _applySchedule(LocationSchedule schedule) {
    _baseSchedule = schedule;
    _maxBreak = schedule.breakLabel;
    _trackLocation = schedule.breakLocationTracking;
    _initialMaxBreak = _maxBreak;
    _initialTrackLocation = _trackLocation;
  }

  Future<void> _load() async {
    if (_isEmployeeContext) {
      final userId = widget.userId!;
      setState(() => _loading = true);
      final result =
          await bindings.managerEmployeesService.loadEmployeeSchedule(
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        if (result.success && result.data != null) {
          _applySchedule(result.data!);
        }
        _loading = false;
      });
      LocationPolicyLog.dump(
        sheet: 'Break Timing',
        phase: 'fetched',
        schedule: result.data ?? _baseSchedule,
        success: result.success,
        statusCode: result.statusCode,
        message: result.message,
        api: 'GET /manager/employees/$userId/permissions',
        extra: {'userId': userId, 'via': 'employee_permissions'},
      );
      return;
    }

    final locationId = widget.locationId?.trim();
    if (locationId == null || locationId.isEmpty) return;

    setState(() => _loading = true);
    final result = await bindings.managerLocationsService
        .loadLocationSchedule(locationId: locationId);
    if (!mounted) return;
    setState(() {
      if (result.success && result.data != null) {
        _applySchedule(result.data!);
      }
      _loading = false;
    });
    LocationPolicyLog.dump(
      sheet: 'Break Timing',
      phase: 'fetched',
      locationId: locationId,
      schedule: result.data ?? _baseSchedule,
      success: result.success,
      statusCode: result.statusCode,
      message: result.message,
      api: 'GET /manager/locations/$locationId/schedule',
    );
  }

  void _reset() {
    setState(() {
      _maxBreak = _initialMaxBreak;
      _trackLocation = _initialTrackLocation;
    });
  }

  LocationSchedule get _currentSchedule {
    return _baseSchedule.copyWith(
      maxBreakMinutes: ManagerEmployeePolicy.parseMinutes(_maxBreak) ?? 60,
      breakLocationTracking: _trackLocation,
    );
  }

  bool _sameBreak(LocationSchedule saved) {
    final wantedMinutes = ManagerEmployeePolicy.parseMinutes(_maxBreak) ?? 60;
    if (saved.maxBreakMinutes != wantedMinutes) return false;
    // Location overrides include tracking; employee portal only has break_time.
    if (!_isEmployeeContext &&
        saved.breakLocationTracking != _trackLocation) {
      return false;
    }
    return true;
  }

  Future<void> _saveViaEmployee(int userId) async {
    setState(() => _saving = true);
    final current = _baseSchedule;
    final next = _currentSchedule;
    final payload = ManagerEmployeePolicy.breakPermissionPayload(
      breakLabel: _maxBreak,
      trackLocation: _trackLocation,
    );
    LocationPolicyLog.dump(
      sheet: 'Break Timing',
      phase: 'current',
      schedule: current,
      apiNeeds: 'break_time',
      extra: {'userId': userId},
    );
    LocationPolicyLog.dump(
      sheet: 'Break Timing',
      phase: 'changed',
      schedule: next,
      api: 'PUT|PATCH /manager/employees/$userId/permissions',
      apiNeeds: 'break_time',
      userSending: payload,
      extra: {'userId': userId},
    );
    final result =
        await bindings.managerEmployeesService.updateEmployeePermissions(
      userId: userId,
      payload: payload,
    );
    if (!mounted) return;

    final verify =
        await bindings.managerEmployeesService.loadEmployeeSchedule(
      userId: userId,
    );
    if (!mounted) return;
    final saved = verify.data;
    final persisted = result.success &&
        verify.success &&
        saved != null &&
        _sameBreak(saved);
    debugPrint(
      '[BreakTiming] employee verify break=${saved?.breakLabel} '
      'wanted=$_maxBreak persisted=$persisted userId=$userId '
      'msg=${result.message}',
    );

    setState(() => _saving = false);
    LocationPolicyLog.dump(
      sheet: 'Break Timing',
      phase: 'response',
      schedule: saved ?? next,
      success: persisted,
      statusCode: verify.statusCode ?? result.statusCode,
      message: verify.message ?? result.message,
      api: 'PUT|PATCH /manager/employees/$userId/permissions',
      extra: {'userId': userId},
    );
    if (!persisted) {
      ToastHelper.error(
        context,
        message: result.success
            ? 'Break timing did not persist. Please try again.'
            : (result.message ?? 'Failed to save break timing.'),
      );
      return;
    }
    final confirmed = saved!.copyWith(
      maxBreakMinutes: ManagerEmployeePolicy.parseMinutes(_maxBreak) ?? 60,
      breakLocationTracking: saved.breakLocationTracking,
    );
    _applySchedule(confirmed);
    if (!mounted) return;
    setState(() {});
    ToastHelper.changesSaved(context);
  }

  Future<void> _saveViaLocation(String locationId) async {
    setState(() => _saving = true);
    final current = _baseSchedule;
    final next = _currentSchedule;
    LocationPolicyLog.dump(
      sheet: 'Break Timing',
      phase: 'current',
      locationId: locationId,
      schedule: current,
      apiNeeds: 'max_break_minutes, break_location_tracking',
    );
    LocationPolicyLog.dump(
      sheet: 'Break Timing',
      phase: 'changed',
      locationId: locationId,
      schedule: next,
      api: 'PUT /manager/locations/$locationId/schedule + /permissions',
      apiNeeds: 'max_break_minutes, break_location_tracking',
    );
    final result = await bindings.managerLocationsService
        .updateLocationSchedule(locationId: locationId, schedule: next);
    if (!mounted) return;

    final verify = await bindings.managerLocationsService
        .loadLocationSchedule(locationId: locationId);
    if (!mounted) return;
    final saved = verify.data;
    final persisted = result.success &&
        verify.success &&
        saved != null &&
        _sameBreak(saved);
    debugPrint(
      '[BreakTiming] location verify break=${saved?.breakLabel} '
      'tracking=${saved?.breakLocationTracking} '
      'wanted=$_maxBreak/$_trackLocation persisted=$persisted '
      'locationId=$locationId',
    );

    setState(() => _saving = false);
    LocationPolicyLog.dump(
      sheet: 'Break Timing',
      phase: 'response',
      locationId: locationId,
      schedule: saved ?? next,
      success: persisted,
      statusCode: verify.statusCode ?? result.statusCode,
      message: verify.message ?? result.message,
      api: 'PUT /manager/locations/$locationId/schedule + /permissions',
    );
    if (!persisted) {
      ToastHelper.error(
        context,
        message: result.success
            ? 'Break timing did not persist. Please try again.'
            : (result.message ?? 'Failed to save break timing.'),
      );
      return;
    }
    final confirmed = saved!.copyWith(
      maxBreakMinutes: ManagerEmployeePolicy.parseMinutes(_maxBreak) ?? 60,
      breakLocationTracking: _trackLocation,
    );
    _applySchedule(confirmed);
    if (!mounted) return;
    setState(() {});
    ToastHelper.changesSaved(context);
  }

  Future<void> _save() async {
    if (_isEmployeeContext) {
      await _saveViaEmployee(widget.userId!);
      return;
    }

    final locationId = widget.locationId?.trim();
    if (locationId != null && locationId.isNotEmpty) {
      await _saveViaLocation(locationId);
      return;
    }

    _initialMaxBreak = _maxBreak;
    _initialTrackLocation = _trackLocation;
    if (!mounted) return;
    setState(() {});
    ToastHelper.changesSaved(context);
  }

  Future<void> _pickDuration() async {
    final result = await AppSheet.show<String>(
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
                          'Max break duration',
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
                ..._durationOptions.map(
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
                          if (option == _maxBreak)
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
    if (result != null && mounted) setState(() => _maxBreak = result);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: AppSheetSize.constraintsOf(context),
      child: Container(
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText.h5(
                        'Break Timing',
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
                child: Container(
                  color: kbackground2,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 64),
                          child: ShimmerProgress(),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                10,
                                20,
                                12,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AppText.p1(
                                  'Enable or disable employee break timings.',
                                  color: kGreyColor,
                                  weight: FontWeight.w400,
                                  align: TextAlign.left,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              decoration: BoxDecoration(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: kBorderColor),
                              ),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _pickDuration,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: AppText.p2(
                                              'Set max break duration',
                                              color: kBlack,
                                              weight: FontWeight.w500,
                                              align: TextAlign.left,
                                            ),
                                          ),
                                          AppText.p2(
                                            _maxBreak,
                                            color: kGreyColor,
                                            weight: FontWeight.w500,
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 18,
                                            color: kGreyColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(
                                    height: 1,
                                    color: kDividerColor,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: AppText.p2(
                                            'Break location tracking',
                                            color: kBlack,
                                            weight: FontWeight.w500,
                                            align: TextAlign.left,
                                          ),
                                        ),
                                        CustomSwitch(
                                          value: _trackLocation,
                                          onChanged: (v) => setState(
                                            () => _trackLocation = v,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                20,
                                20,
                                12,
                              ),
                              child: AppText.p1(
                                'Breaks can only be started and ended when the employee is within office/location premises.',
                                color: kGreyColor,
                                align: TextAlign.left,
                              ),
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
                      flex: 3,
                      child: MyButton(
                        buttonText: 'Save',
                        backgroundColor: kPrimaryButtonColor,
                        isLoadingExternally: _saving,
                        isactive: !_saving && !_loading,
                        onTap: _save,
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
