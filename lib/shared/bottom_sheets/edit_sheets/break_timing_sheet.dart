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
    return showModalBottomSheet<LocationSchedule>(
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
    final locationId = widget.locationId?.trim();
    if (locationId != null && locationId.isNotEmpty) {
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
        sheet: 'break_timing',
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

  Future<void> _save() async {
    final locationId = widget.locationId?.trim();
    if (locationId != null && locationId.isNotEmpty) {
      setState(() => _saving = true);
      final current = _baseSchedule;
      final next = _currentSchedule;
      LocationPolicyLog.dump(
        sheet: 'break_timing',
        phase: 'current',
        locationId: locationId,
        schedule: current,
      );
      LocationPolicyLog.dump(
        sheet: 'break_timing',
        phase: 'changed',
        locationId: locationId,
        schedule: next,
      );
      final result = await bindings.managerLocationsService
          .updateLocationSchedule(locationId: locationId, schedule: next);
      if (!mounted) return;
      setState(() => _saving = false);
      LocationPolicyLog.dump(
        sheet: 'break_timing',
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
          message: result.message ?? 'Failed to save break timing.',
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
      setState(() => _saving = true);
      final wantedBreak = _maxBreak;
      final wantedTracking = _trackLocation;
      final next = _currentSchedule;
      final result = await bindings.managerEmployeesService
          .updateEmployeeSchedule(
            userId: widget.userId!,
            payload: {
              ...ManagerEmployeePolicy.breakPermissionPayload(
                breakLabel: wantedBreak,
                trackLocation: wantedTracking,
              ),
              ...next.writePayload(),
            },
          );
      if (!mounted) return;
      if (!result.success) {
        setState(() => _saving = false);
        ToastHelper.error(
          context,
          message: result.message ?? 'Failed to save break timing.',
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
          message: verify.message ?? 'Break update could not be confirmed.',
        );
        return;
      }
      final saved = verify.data!;
      if (saved.breakLabel != wantedBreak ||
          saved.breakLocationTracking != wantedTracking) {
        ToastHelper.error(
          context,
          message: 'Break timing did not persist. Please try again.',
        );
        return;
      }
      _applySchedule(saved);
    }

    _initialMaxBreak = _maxBreak;
    _initialTrackLocation = _trackLocation;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rootContext.mounted) return;
      ToastHelper.changesSaved(rootContext);
    });
  }

  Future<void> _pickDuration() async {
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
            Expanded(
              child: Container(
                color: kbackground2,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 20, 12),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                          const Divider(height: 1, color: kDividerColor),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
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
                                SizedBox(
                                  width: 55,
                                  height: 40,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Switch.adaptive(
                                      value: _trackLocation,
                                      activeColor: kPrimaryColor,
                                      thumbColor: MaterialStateProperty.all(
                                        kWhite,
                                      ),
                                      trackColor: MaterialStateProperty.all(
                                        kPrimaryColor,
                                      ),
                                      onChanged: (v) =>
                                          setState(() => _trackLocation = v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 20, 12),
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
    );
  }
}
