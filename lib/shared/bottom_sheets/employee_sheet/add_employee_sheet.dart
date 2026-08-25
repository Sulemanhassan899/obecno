import 'dart:async';

import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/date_picker.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/invite_sent_dialog.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/custom_textfield.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _InviteRow {
  _InviteRow({this.locationId = LocationFilterOption.allId});

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController jobTitleController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();

  String locationId;
  final extraLocationIds = <String>{};
  String? departmentId;
  String? gender;
  String? countryId;
  String? cityId;
  String? reportsToId;
  int status = 0;
  DateTime? dateOfBirth;
  DateTime? joiningDate;
  final errors = <String, String?>{};

  String? error(String key) => errors[key];

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    jobTitleController.dispose();
    cnicController.dispose();
  }

  void clearErrors() => errors.clear();
}

class AddEmployeeSheet {
  AddEmployeeSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddEmployeeSheetBody(),
    );
  }
}

class _AddEmployeeSheetBody extends StatefulWidget {
  const _AddEmployeeSheetBody();

  @override
  State<_AddEmployeeSheetBody> createState() => _AddEmployeeSheetBodyState();
}

class _AddEmployeeSheetBodyState extends State<_AddEmployeeSheetBody> {
  final _rows = <_InviteRow>[_InviteRow()];
  static const _inviteLink = 'https://www.obecno.com/EmployeeRegister...';
  static const _genders = [
    ManagerDepartmentOption(id: 'male', name: 'Male'),
    ManagerDepartmentOption(id: 'female', name: 'Female'),
    ManagerDepartmentOption(id: 'other', name: 'Other'),
  ];
  static const _statuses = [
    ManagerDepartmentOption(id: '0', name: 'Pending'),
    ManagerDepartmentOption(id: '1', name: 'Active'),
    ManagerDepartmentOption(id: '2', name: 'Disabled'),
  ];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final employees = context.read<ManagerEmployeesProvider>();
      final locations = context.read<ManagerLocationsProvider>();
      final currentUserId = context.read<AuthProvider>().user?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        _rows.first.reportsToId = currentUserId;
      }
      unawaited(employees.loadAddEmployeeLookups());
      unawaited(locations.load());
    });
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String _lookupLabel(
    List<ManagerDepartmentOption> options,
    String? id,
    String placeholder,
  ) {
    if (id == null || id.trim().isEmpty) return placeholder;
    for (final option in options) {
      if (option.id == id) return option.name;
    }
    return placeholder;
  }

  String _locationLabel(String id) {
    if (!AddEmployeePayload.hasLocation(id)) return 'Select location';
    return context.read<ManagerLocationsProvider>().byId(id)?.name ??
        'Select location';
  }

  String _extraLocationsLabel(_InviteRow row) {
    final locations = context.read<ManagerLocationsProvider>();
    final ids = row.extraLocationIds
        .where(AddEmployeePayload.hasLocation)
        .toList(growable: false);
    if (ids.isEmpty) return 'None selected';
    final names = ids
        .map((id) => locations.byId(id)?.name ?? id)
        .toList(growable: false);
    return names.join(', ');
  }

  String _reportsToLabel(_InviteRow row) {
    final id = row.reportsToId;
    if (id == null || id.isEmpty) return 'Select manager';
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser != null && currentUser.id == id) {
      return '${currentUser.name} (You)';
    }
    return _lookupLabel(
      context.read<ManagerEmployeesProvider>().reportsToOptions,
      id,
      'Select manager',
    );
  }

  String _dateLabel(DateTime? date, String placeholder) {
    if (date == null) return placeholder;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<String?> _pickOption({
    required String title,
    required List<ManagerDepartmentOption> options,
    String? selectedId,
    String emptyMessage = 'No options found.',
  }) async {
    if (options.isEmpty) {
      ToastHelper.error(context, message: emptyMessage);
      return null;
    }
    return showModalBottomSheet<String>(
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
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: kDividerColor),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      final isSelected = option.id == selectedId;
                      return ListTile(
                        title: AppText.p2(
                          option.name,
                          weight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          align: TextAlign.left,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: kPrimaryColor)
                            : null,
                        onTap: () => Navigator.pop(sheetContext, option.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDepartment(_InviteRow row) async {
    final provider = context.read<ManagerEmployeesProvider>();
    if (provider.departmentOptions.isEmpty) {
      await provider.loadDepartments();
      if (!mounted) return;
    }
    final selected = await _pickOption(
      title: 'Select Department',
      options: provider.departmentOptions,
      selectedId: row.departmentId,
      emptyMessage: 'No departments found.',
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.departmentId = selected;
      row.errors.remove('department_id');
    });
  }

  Future<void> _pickLocation(_InviteRow row) async {
    final locationsProvider = context.read<ManagerLocationsProvider>();
    await locationsProvider.load();
    if (!mounted) return;
    final selected = await LocationsFilterSheet.show(
      context,
      locations: locationsProvider.filterOptions,
      selectedId: row.locationId,
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.locationId = selected;
      row.errors.remove('location_id');
      row.errors.remove('default_location_id');
    });
  }

  Future<void> _pickExtraLocations(_InviteRow row) async {
    final locationsProvider = context.read<ManagerLocationsProvider>();
    await locationsProvider.load();
    if (!mounted) return;
    final options = locationsProvider.filterOptions
        .where((item) => AddEmployeePayload.hasLocation(item.id))
        .toList(growable: false);
    if (options.isEmpty) {
      ToastHelper.error(context, message: 'No locations found.');
      return;
    }
    final selected = Set<String>.from(row.extraLocationIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                              'Assigned Locations',
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: kDividerColor),
                        itemBuilder: (_, index) {
                          final option = options[index];
                          final isChecked = selected.contains(option.id);
                          return CheckboxListTile(
                            value: isChecked,
                            activeColor: kPrimaryColor,
                            title: AppText.p2(
                              option.name,
                              weight: FontWeight.w500,
                              align: TextAlign.left,
                            ),
                            onChanged: (checked) {
                              setSheetState(() {
                                if (checked == true) {
                                  selected.add(option.id);
                                } else {
                                  selected.remove(option.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: MyButton(
                        buttonText: 'Done',
                        backgroundColor: kPrimaryColor,
                        onTap: () async =>
                            Navigator.pop(sheetContext, selected),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      row.extraLocationIds
        ..clear()
        ..addAll(result);
      row.errors.remove('location_ids');
    });
  }

  Future<void> _pickGender(_InviteRow row) async {
    final selected = await _pickOption(
      title: 'Select Gender',
      options: _genders,
      selectedId: row.gender,
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.gender = selected;
      row.errors.remove('gender');
    });
  }

  Future<void> _pickCountry(_InviteRow row) async {
    final provider = context.read<ManagerEmployeesProvider>();
    if (provider.countries.isEmpty) {
      await provider.loadCountries();
      if (!mounted) return;
    }
    final selected = await _pickOption(
      title: 'Select Country',
      options: provider.countries,
      selectedId: row.countryId,
      emptyMessage: 'No countries found.',
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.countryId = selected;
      row.cityId = null;
      row.errors.remove('country_id');
      row.errors.remove('city_id');
    });
    await provider.loadCities(selected);
  }

  Future<void> _pickCity(_InviteRow row) async {
    if (row.countryId == null || row.countryId!.isEmpty) {
      ToastHelper.error(context, message: 'Select a country first.');
      return;
    }
    final provider = context.read<ManagerEmployeesProvider>();
    await provider.loadCities(row.countryId!);
    if (!mounted) return;
    final selected = await _pickOption(
      title: 'Select City',
      options: provider.cities,
      selectedId: row.cityId,
      emptyMessage: 'No cities found.',
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.cityId = selected;
      row.errors.remove('city_id');
    });
  }

  Future<void> _pickReportsTo(_InviteRow row) async {
    final provider = context.read<ManagerEmployeesProvider>();
    if (provider.reportsToOptions.isEmpty) {
      await provider.load();
      if (!mounted) return;
    }
    final currentUser = context.read<AuthProvider>().user;
    final options = [
      if (currentUser != null)
        ManagerDepartmentOption(
          id: currentUser.id,
          name: '${currentUser.name} (You)',
        ),
      ...provider.reportsToOptions.where(
        (option) => option.id != currentUser?.id,
      ),
    ];
    final selected = await _pickOption(
      title: 'Reports To',
      options: options,
      selectedId: row.reportsToId,
      emptyMessage: 'No managers found.',
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.reportsToId = selected;
      row.errors.remove('reportsto_id');
    });
  }

  Future<void> _pickStatus(_InviteRow row) async {
    final selected = await _pickOption(
      title: 'Select Status',
      options: _statuses,
      selectedId: '${row.status}',
    );
    if (selected == null || !mounted) return;
    setState(() {
      row.status = int.tryParse(selected) ?? 0;
      row.errors.remove('status');
    });
  }

  void _pickDate({
    required _InviteRow row,
    required String key,
    required DateTime? current,
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) {
    DateMonthYearPickerSheet.show(
      context,
      initialDate: current ?? initialDate,
      onSelected: (date) {
        setState(() {
          onSelected(date);
          row.errors.remove(key);
        });
      },
    );
  }

  void _clear() {
    for (final row in _rows) {
      row.dispose();
    }
    final currentUserId = context.read<AuthProvider>().user?.id;
    setState(() {
      _rows
        ..clear()
        ..add(_InviteRow()..reportsToId = currentUserId);
    });
  }

  bool _validate(_InviteRow row) {
    row.clearErrors();
    final name = row.nameController.text.trim();
    final email = row.emailController.text.trim();
    final jobTitle = row.jobTitleController.text.trim();
    if (name.isEmpty) row.errors['name'] = 'Name is required.';
    if (email.isEmpty) {
      row.errors['email'] = 'Email is required.';
    } else if (!AddEmployeePayload.isValidEmail(email)) {
      row.errors['email'] = 'Enter a valid email address.';
    }
    if (jobTitle.isEmpty) row.errors['job_title'] = 'Job title is required.';
    if (!AddEmployeePayload.hasDepartment(row.departmentId)) {
      row.errors['department_id'] = 'Department is required.';
    }
    if (!AddEmployeePayload.hasLocation(row.locationId)) {
      row.errors['location_id'] = 'Location is required.';
    }
    return row.errors.isEmpty;
  }

  Future<void> _sendInvites() async {
    if (_sending) return;
    debugPrint('[AddEmployee] Send Invites tapped');

    var hasFieldError = false;
    final invites = <AddEmployeePayload>[];
    for (final row in _rows) {
      if (!_validate(row)) {
        hasFieldError = true;
        continue;
      }
      invites.add(
        AddEmployeePayload.fromInvite(
          name: row.nameController.text.trim(),
          email: row.emailController.text.trim(),
          phone: row.phoneController.text.trim(),
          jobTitle: row.jobTitleController.text.trim(),
          gender: row.gender,
          departmentId: row.departmentId!,
          locationId: row.locationId,
          extraLocationIds: row.extraLocationIds.toList(growable: false),
          countryId: row.countryId,
          cityId: row.cityId,
          dateOfBirth: row.dateOfBirth,
          joiningDate: row.joiningDate,
          cnic: row.cnicController.text.trim(),
          status: row.status,
          reportsToId: row.reportsToId,
        ),
      );
    }

    if (hasFieldError) {
      debugPrint('[AddEmployee] blocked by local validation');
      setState(() {});
      ToastHelper.error(
        context,
        message: 'Fill the required fields before sending invites.',
      );
      return;
    }

    if (invites.isEmpty) {
      setState(() => _rows.first.errors['email'] = 'Email is required.');
      return;
    }

    setState(() => _sending = true);
    debugPrint('[AddEmployee] calling API for ${invites.length} invite(s)');
    try {
      final result = await context.read<ManagerEmployeesProvider>().addEmployees(
        invites,
      );
      debugPrint(
        '[AddEmployee] UI result success=${result.success} '
        'code=${result.statusCode} message=${result.message} '
        'fields=${result.fieldErrors}',
      );
      if (!mounted) return;
      setState(() => _sending = false);

      if (!result.success) {
        _applyApiErrors(result);
        ToastHelper.error(
          context,
          message: result.message ?? 'Failed to send invites.',
        );
        return;
      }

      unawaited(context.read<ManagerEmployeesProvider>().refresh());
      unawaited(context.read<ManagerOverviewProvider>().refresh());

      final navigator = Navigator.of(context, rootNavigator: true);
      debugPrint('[AddEmployee] invite succeeded, showing dialog');
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint(
          '[AddEmployee] dialog frame navigator.mounted=${navigator.mounted}',
        );
        if (!navigator.mounted) return;
        InviteSentDialog.show(navigator.context);
      });
    } catch (error, stack) {
      debugPrint('[AddEmployee] Send Invites failed: $error');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() => _sending = false);
      ToastHelper.error(context, message: error.toString());
    }
  }

  void _applyApiErrors(ApiResponse<dynamic> result) {
    const keys = [
      'name',
      'email',
      'phone',
      'job_title',
      'gender',
      'department_id',
      'location_id',
      'location_ids',
      'default_location_id',
      'country_id',
      'city_id',
      'date_of_birth',
      'joining_date',
      'cnic',
      'status',
      'reportsto_id',
    ];
    setState(() {
      var applied = false;
      for (final row in _rows) {
        if (row.emailController.text.trim().isEmpty) continue;
        for (final key in keys) {
          row.errors[key] = result.messageForFields([key]);
        }
        applied = true;
      }
      final target = applied ? null : _rows.first;
      if (target != null) {
        for (final key in keys) {
          target.errors[key] = result.messageForFields([key]);
        }
      }
      final hasField = keys.any(
        (key) => result.messageForFields([key]) != null,
      );
      if (!hasField) {
        (_rows.first).errors['email'] =
            result.firstFieldMessage ?? result.message;
      }
    });
  }

  Future<void> _shareLink() async {
    await Clipboard.setData(const ClipboardData(text: _inviteLink));
  }

  Widget _addViaLinkCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          CommonImageView(imagePath: Assets.linkIcon, height: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.p2(
                  'Add via link',
                  color: kBlack,
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 4),
                AppText.caption(
                  _inviteLink,
                  color: kGreyColor,
                  weight: FontWeight.w400,
                  align: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ButtonAnimations.press(
            onTap: _shareLink,
            child: CommonImageView(imagePath: Assets.ShareButton, height: 40),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String errorKey,
    required _InviteRow row,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return CustomTextField(
      controller: controller,
      hintText: '',
      labelText: label,
      haveLebelText: true,
      hasStar: required,
      backgroundColor: kWhite,
      enabledBorderColor: kBorderColor,
      focusedBorderColor: kBorderColor,
      radius: 12,
      keyboardType: keyboardType ?? TextInputType.text,
      errorText: row.error(errorKey),
      onChanged: (_) {
        if (row.error(errorKey) == null) return;
        setState(() => row.errors.remove(errorKey));
      },
    );
  }

  Widget _inviteFormCard(_InviteRow row) {
    final employees = context.watch<ManagerEmployeesProvider>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(
            controller: row.nameController,
            label: 'Name',
            errorKey: 'name',
            row: row,
            required: true,
          ),
          _textField(
            controller: row.emailController,
            label: 'Email',
            errorKey: 'email',
            row: row,
            required: true,
            keyboardType: TextInputType.emailAddress,
          ),
          _textField(
            controller: row.phoneController,
            label: 'Phone',
            errorKey: 'phone',
            row: row,
            keyboardType: TextInputType.phone,
          ),
          _textField(
            controller: row.jobTitleController,
            label: 'Job title',
            errorKey: 'job_title',
            row: row,
            required: true,
          ),
          _selectField(
            label: 'Gender',
            value: _lookupLabel(_genders, row.gender, 'Select gender'),
            error: row.error('gender'),
            onTap: () => _pickGender(row),
          ),
          const SizedBox(height: 12),
          _selectField(
            label: 'Department',
            value: _lookupLabel(
              employees.departmentOptions,
              row.departmentId,
              'Select department',
            ),
            error: row.error('department_id'),
            required: true,
            onTap: () => _pickDepartment(row),
          ),
          const SizedBox(height: 12),
          _selectField(
            label: 'Location',
            value: _locationLabel(row.locationId),
            error: row.error('location_id') ?? row.error('default_location_id'),
            required: true,
            onTap: () => _pickLocation(row),
          ),
          const SizedBox(height: 12),
          _selectField(
            label: 'Assigned locations',
            value: _extraLocationsLabel(row),
            error: row.error('location_ids'),
            onTap: () => _pickExtraLocations(row),
          ),
          const SizedBox(height: 12),
          _selectField(
            label: 'Country',
            value: _lookupLabel(
              employees.countries,
              row.countryId,
              'Select country',
            ),
            error: row.error('country_id'),
            onTap: () => _pickCountry(row),
          ),
          const SizedBox(height: 12),
          _selectField(
            label: 'City',
            value: _lookupLabel(employees.cities, row.cityId, 'Select city'),
            error: row.error('city_id'),
            onTap: () => _pickCity(row),
          ),
          const SizedBox(height: 12),
          _selectField(
            label: 'Date of birth',
            value: _dateLabel(row.dateOfBirth, 'Select date'),
            error: row.error('date_of_birth'),
            onTap: () => _pickDate(
              row: row,
              key: 'date_of_birth',
              current: row.dateOfBirth,
              initialDate: DateTime(1995, 1, 1),
              onSelected: (date) => row.dateOfBirth = date,
            ),
          ),
          const SizedBox(height: 12),
          _selectField(
            label: 'Joining date',
            value: _dateLabel(row.joiningDate, 'Select date'),
            error: row.error('joining_date'),
            onTap: () => _pickDate(
              row: row,
              key: 'joining_date',
              current: row.joiningDate,
              initialDate: DateTime.now(),
              onSelected: (date) => row.joiningDate = date,
            ),
          ),
          const SizedBox(height: 12),
          _textField(
            controller: row.cnicController,
            label: 'CNIC',
            errorKey: 'cnic',
            row: row,
          ),
          _selectField(
            label: 'Status',
            value: _lookupLabel(_statuses, '${row.status}', 'Select status'),
            error: row.error('status'),
            onTap: () => _pickStatus(row),
          ),
          const SizedBox(height: 12),
          _selectField(
            label: 'Reports to',
            value: _reportsToLabel(row),
            error: row.error('reportsto_id'),
            onTap: () => _pickReportsTo(row),
          ),
        ],
      ),
    );
  }

  Widget _selectField({
    required String label,
    required String value,
    required VoidCallback onTap,
    String? error,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppText.caption(
              label,
              color: error != null ? kRed : kBlack,
              weight: FontWeight.w500,
              align: TextAlign.left,
            ),
            if (required)
              AppText.caption(
                ' *',
                color: kRed,
                weight: FontWeight.w600,
              ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: error != null ? kRed : kBorderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppText.p2(
                    value,
                    color: kBlack,
                    weight: FontWeight.w500,
                    align: TextAlign.left,
                  ),
                ),
                const Icon(Icons.unfold_more, size: 18, color: kGreyColor),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          AppText.caption(
            error,
            color: kRed,
            weight: FontWeight.w400,
            align: TextAlign.left,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ManagerEmployeesProvider>();
    context.watch<ManagerLocationsProvider>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText.h5(
                        'Add Employee',
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _addViaLinkCard(),
                        const SizedBox(height: 22),
                        AppText.p2(
                          'Add Employees',
                          color: kBlack,
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 10),
                        ..._rows.asMap().entries.map((entry) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.key == _rows.length - 1 ? 0 : 12,
                            ),
                            child: _inviteFormCard(entry.value),
                          );
                        }),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ButtonAnimations.press(
                            onTap: () => setState(() {
                              final row = _InviteRow();
                              row.reportsToId =
                                  context.read<AuthProvider>().user?.id;
                              _rows.add(row);
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: kBorderColor),
                              ),
                              child: AppText.caption(
                                '+ Add Another',
                                color: kGreyColor,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                        buttonText: 'Clear',
                        backgroundColor: kWhite,
                        fontColor: kBlack,
                        outlineColor: kBorderColor,
                        isactive: !_sending,
                        onTap: () async => _clear(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: MyButton(
                        buttonText: 'Send Invites',
                        backgroundColor: kPrimaryColor,
                        isactive: !_sending,
                        isLoadingExternally: _sending,
                        onTap: _sendInvites,
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
