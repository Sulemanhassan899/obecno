class AddEmployeePayload {
  const AddEmployeePayload({
    required this.email,
    this.name,
    this.phone,
    this.jobTitle,
    this.gender,
    this.departmentId,
    this.locationIds = const [],
    this.locationId,
    this.defaultLocationId,
    this.countryId,
    this.cityId,
    this.dateOfBirth,
    this.joiningDate,
    this.cnic,
    this.status,
    this.reportsToId,
  });

  final String email;
  final String? name;
  final String? phone;
  final String? jobTitle;
  final String? gender;
  final int? departmentId;
  final List<Object> locationIds;
  final Object? locationId;
  final Object? defaultLocationId;
  final int? countryId;
  final int? cityId;
  final DateTime? dateOfBirth;
  final DateTime? joiningDate;
  final String? cnic;
  final int? status;
  final int? reportsToId;

  static final emailPattern = RegExp(
    r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$',
  );

  static bool isValidEmail(String email) =>
      emailPattern.hasMatch(email.trim());

  static String nameFromEmail(String email) {
    final local = email.trim().split('@').first.replaceAll(
      RegExp(r'[^A-Za-z._\-]+'),
      '',
    );
    final parts = local
        .split(RegExp(r'[._\-]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
          final value = part.trim();
          if (value.isEmpty) return value;
          return '${value[0].toUpperCase()}${value.substring(1)}';
        })
        .toList(growable: false);
    if (parts.isEmpty) return 'Employee';
    return parts.join(' ');
  }

  factory AddEmployeePayload.fromInvite({
    required String email,
    String locationId = '',
    String jobTitle = '',
    String departmentId = '',
    String? name,
    String? phone,
    String? gender,
    List<String> extraLocationIds = const [],
    String? countryId,
    String? cityId,
    DateTime? dateOfBirth,
    DateTime? joiningDate,
    String? cnic,
    int? status,
    String? reportsToId,
  }) {
    final location = locationRef(locationId);
    final locationIds = <Object>[
      if (location != null) location,
    ];
    for (final extra in extraLocationIds) {
      final value = locationRef(extra);
      if (value == null || value == location) continue;
      locationIds.add(value);
    }
    final trimmedName = name?.trim() ?? '';
    return AddEmployeePayload(
      email: email.trim(),
      name: trimmedName.isNotEmpty ? trimmedName : nameFromEmail(email),
      phone: phone?.trim(),
      jobTitle: jobTitle.trim(),
      gender: gender?.trim(),
      departmentId: int.tryParse(departmentId.trim()),
      locationIds: locationIds,
      locationId: location,
      defaultLocationId: location,
      countryId: int.tryParse(countryId?.trim() ?? ''),
      cityId: int.tryParse(cityId?.trim() ?? ''),
      dateOfBirth: dateOfBirth,
      joiningDate: joiningDate,
      cnic: cnic?.trim(),
      status: status,
      reportsToId: int.tryParse(reportsToId?.trim() ?? ''),
    );
  }

  static bool hasLocation(String? raw) => locationRef(raw) != null;

  static bool hasDepartment(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'all') return false;
    return int.tryParse(value) != null;
  }

  static Object? locationRef(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'all') return null;
    return int.tryParse(value) ?? value;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (_hasText(name)) 'name': name!.trim(),
      'email': email.trim(),
      if (_hasText(phone)) 'phone': phone!.trim(),
      if (_hasText(jobTitle)) 'job_title': jobTitle!.trim(),
      if (_hasText(gender)) 'gender': gender!.trim(),
      if (departmentId != null) 'department_id': departmentId,
      if (locationIds.isNotEmpty) 'location_ids': locationIds,
      if (locationId != null) 'location_id': locationId,
      if (defaultLocationId != null) 'default_location_id': defaultLocationId,
      if (countryId != null) 'country_id': countryId,
      if (cityId != null) 'city_id': cityId,
      if (dateOfBirth != null) 'date_of_birth': _date(dateOfBirth!),
      if (joiningDate != null) 'joining_date': _date(joiningDate!),
      if (_hasText(cnic)) 'cnic': cnic!.trim(),
      if (status != null) 'status': status,
      if (reportsToId != null) 'reportsto_id': reportsToId,
    };
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _date(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class ManagerDepartmentOption {
  const ManagerDepartmentOption({required this.id, required this.name});

  final String id;
  final String name;

  int? get intId => int.tryParse(id.trim());
}
