import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';

void main() {
  group('AddEmployeePayload', () {
    test('sends every provided profile field', () {
      final payload = AddEmployeePayload.fromInvite(
        email: 'jane.doe@company.com',
        locationId: '12',
        jobTitle: 'Designer',
        departmentId: '4',
        name: 'Jane Doe',
        phone: '03001234567',
        gender: 'female',
        extraLocationIds: ['15'],
        countryId: '1',
        cityId: '9',
        dateOfBirth: DateTime(1994, 2, 3),
        joiningDate: DateTime(2026, 8, 24),
        cnic: '35202-1234567-1',
        status: 0,
        reportsToId: '88',
      );

      expect(payload.toJson(), {
        'name': 'Jane Doe',
        'email': 'jane.doe@company.com',
        'phone': '03001234567',
        'job_title': 'Designer',
        'gender': 'female',
        'department_id': 4,
        'location_ids': [12, 15],
        'location_id': 12,
        'default_location_id': 12,
        'country_id': 1,
        'city_id': 9,
        'date_of_birth': '1994-02-03',
        'joining_date': '2026-08-24',
        'cnic': '35202-1234567-1',
        'status': 0,
        'reportsto_id': 88,
      });
    });

    test('treats all-location as missing', () {
      expect(AddEmployeePayload.hasLocation('all'), isFalse);
      expect(AddEmployeePayload.hasLocation(''), isFalse);
      expect(AddEmployeePayload.hasLocation('12'), isTrue);
      expect(AddEmployeePayload.hasDepartment('all'), isFalse);
      expect(AddEmployeePayload.hasDepartment(''), isFalse);
      expect(AddEmployeePayload.hasDepartment('4'), isTrue);

      final payload = AddEmployeePayload.fromInvite(
        email: 'user@example.com',
        locationId: 'all',
        jobTitle: 'Engineer',
        departmentId: '4',
      );
      expect(payload.toJson(), {
        'name': 'User',
        'email': 'user@example.com',
        'job_title': 'Engineer',
        'department_id': 4,
      });
    });

    test('strips digits from generated names', () {
      expect(
        AddEmployeePayload.nameFromEmail('mesulemanhassan899@gmail.com'),
        'Mesulemanhassan',
      );
    });

    test('validates emails', () {
      expect(AddEmployeePayload.isValidEmail('user@example.com'), isTrue);
      expect(AddEmployeePayload.isValidEmail('bad@'), isFalse);
      expect(AddEmployeePayload.isValidEmail(''), isFalse);
    });
  });
}
