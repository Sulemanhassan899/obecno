import 'package:Obecno/core/api/constants.dart';

/// A single (id, name) option from one of the profile endpoint's lookup
/// lists -- `countries`, `cities`, `departments`.
class LookupItem {
  const LookupItem({required this.id, required this.name});

  final String id;
  final String name;

  factory LookupItem.fromJson(Map<String, dynamic> json) {
    return LookupItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? json['label'] ?? '').toString(),
    );
  }

  /// Tolerant list parser -- returns `const []` instead of throwing if
  /// [raw] is missing, null, or not a list (mirrors the defensive style
  /// used by `AuthUserModel.fromJson`).
  static List<LookupItem> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LookupItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  String toString() => 'LookupItem(id: $id, name: $name)';
}

/// Response model for `GET /api/employee/profile` and
/// `PUT /api/employee/profile` -- both return the same "profile data with
/// countries, cities, and departments" shape per the API docs, so one
/// model covers both.
class EmployeeProfileModel {
  const EmployeeProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.designation,
    this.employeeCode,
    this.address,
    this.countryId,
    this.cityId,
    this.departmentId,
    this.countries = const [],
    this.cities = const [],
    this.departments = const [],
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String? designation;
  final String? employeeCode;
  final String? address;
  final String? countryId;
  final String? cityId;
  final String? departmentId;

  /// Dropdown options for the edit-profile form. Empty on responses that
  /// don't include them (e.g. after a photo-only update, if the backend
  /// omits the lookup lists there).
  final List<LookupItem> countries;
  final List<LookupItem> cities;
  final List<LookupItem> departments;

  factory EmployeeProfileModel.fromJson(Map<String, dynamic> json) {
    // The actual profile fields may be nested under "profile" or "user",
    // or sit flat at the top level -- same defensive unwrap pattern as
    // AuthUserModel.fromJson, since this backend isn't consistent about it.
    final profile = json['profile'] is Map<String, dynamic>
        ? json['profile'] as Map<String, dynamic>
        : (json['user'] is Map<String, dynamic>
              ? json['user'] as Map<String, dynamic>
              : json);

    // 🔥 FIX: `GET /api/employee/profile` puts the employer's info in a
    // sibling "company" object next to "user", not on the user record
    // itself -- that's where the real Company ID / office address live
    // (an employee has no company_id/address field of their own).
    final company = json['company'] is Map<String, dynamic>
        ? json['company'] as Map<String, dynamic>
        : const <String, dynamic>{};

    // 🔥 FIX: the role shown under the name on the profile header comes
    // back as "job_title" ("Flutter Developer"), not "designation" or
    // "position" -- those keys don't exist in the real response, which is
    // why it rendered blank. Falls back to the first entry of "roles"
    // (e.g. "employee") only if job_title is ever missing.
    String? designation =
        (profile['job_title'] ?? profile['designation'] ?? profile['position'])
            ?.toString();
    if (designation == null || designation.isEmpty) {
      final roles = profile['roles'];
      if (roles is List && roles.isNotEmpty) {
        designation = roles.first.toString();
      }
    }

    // 🔥 FIX: the photo path the backend sends is host-relative
    // ("uploads/users/24-....jpg" on `user.photo`, or "/uploads/..." on
    // the sibling top-level `photo_url`) -- never a full URL. Handing that
    // straight to `Image.network` fails silently, which is why the photo
    // never showed. `photo_url` is preferred since it's the field this
    // endpoint documents for direct display; `_absoluteUrl` resolves
    // whichever one is present against the API's base URL.
    final rawPhoto =
        (json['photo_url'] ??
                profile['photo'] ??
                profile['photo_url'] ??
                profile['avatar'])
            ?.toString();

    return EmployeeProfileModel(
      id: (profile['id'] ?? profile['user_id'] ?? profile['employee_id'] ?? '')
          .toString(),
      name: (profile['name'] ?? profile['title'] ?? profile['full_name'] ?? '')
          .toString(),
      email: (profile['email'] ?? '').toString(),
      phone: (profile['phone'] ?? profile['phone_number'])?.toString(),
      photoUrl: _absoluteUrl(rawPhoto),
      designation: designation,
      // 🔥 FIX: "Company ID" on the Account Info screen is the employer's
      // id (`company.id`), not a field on the user record -- the old
      // `employee_code`/`company_id` keys don't exist on `user`, which is
      // why it always showed "-".
      employeeCode:
          (company['id'] ?? profile['employee_code'] ?? profile['company_id'])
              ?.toString(),
      // 🔥 FIX: same story for "Address" -- it's the company's address,
      // not a field the employee record carries.
      address:
          (company['address'] ??
                  company['office_address'] ??
                  company['location'] ??
                  profile['address'])
              ?.toString(),
      countryId: (profile['country_id'] ?? json['selected_country_id'])
          ?.toString(),
      cityId: (profile['city_id'] ?? json['selected_city_id'])?.toString(),
      departmentId: (profile['department_id'] ?? json['selected_department_id'])
          ?.toString(),
      countries: LookupItem.listFrom(json['countries']),
      cities: LookupItem.listFrom(json['cities']),
      departments: LookupItem.listFrom(json['departments']),
    );
  }

  /// Resolves a host-relative backend path ("uploads/..." or
  /// "/uploads/...") into an absolute URL `Image.network` can load.
  /// Leaves an already-absolute URL (http/https) untouched, and returns
  /// null for a missing/empty path instead of building a bare base URL.
  static String? _absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final base = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$base$normalizedPath';
  }

  /// Used by `ProfileProvider.updatePhoto` so a photo-only response (which
  /// may omit the lookup lists) doesn't wipe out the countries/cities/
  /// departments already loaded from the last full `getProfile()` call.
  EmployeeProfileModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? designation,
    String? employeeCode,
    String? address,
    String? countryId,
    String? cityId,
    String? departmentId,
    List<LookupItem>? countries,
    List<LookupItem>? cities,
    List<LookupItem>? departments,
  }) {
    return EmployeeProfileModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      designation: designation ?? this.designation,
      employeeCode: employeeCode ?? this.employeeCode,
      address: address ?? this.address,
      countryId: countryId ?? this.countryId,
      cityId: cityId ?? this.cityId,
      departmentId: departmentId ?? this.departmentId,
      countries: (countries != null && countries.isNotEmpty)
          ? countries
          : this.countries,
      cities: (cities != null && cities.isNotEmpty) ? cities : this.cities,
      departments: (departments != null && departments.isNotEmpty)
          ? departments
          : this.departments,
    );
  }

  @override
  String toString() =>
      'EmployeeProfileModel(id: $id, name: $name, email: $email)';
}
