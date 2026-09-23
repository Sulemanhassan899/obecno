import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/auth/data/models/auth_user_model.dart';

void main() {
  group('AuthLocationModel default office', () {
    test('keeps is_default from the location payload', () {
      final locations = AuthLocationModel.listFrom([
        {'id': '1', 'name': 'Head Office', 'is_default': true},
        {'id': '2', 'name': 'North Office', 'is_default': false},
      ], defaultLocationId: '2');

      expect(locations[0].isDefault, isTrue);
      expect(locations[1].isDefault, isFalse);
    });

    test('applies default_location_id when locations omit is_default', () {
      final locations = AuthLocationModel.listFrom([
        {'id': '1', 'name': 'Head Office'},
        {'id': '2', 'name': 'North Office'},
      ], defaultLocationId: '1');

      expect(locations[0].isDefault, isTrue);
      expect(locations[1].isDefault, isFalse);
    });

    test('does not treat a working-location id as the default', () {
      final preserved = AuthLocationModel.applyDefaultFlag(const [
        AuthLocationModel(id: '1', name: 'Head Office', isDefault: true),
        AuthLocationModel(id: '2', name: 'North Office'),
      ], '2');

      expect(preserved[0].isDefault, isTrue);
      expect(preserved[1].isDefault, isFalse);
    });
  });

  group('AuthUserModel default office', () {
    test('marks default from user.default_location_id', () {
      final user = AuthUserModel.fromJson({
        'id': 1,
        'name': 'Ava',
        'email': 'ava@example.com',
        'default_location_id': '9',
        'locations': [
          {'id': '5', 'name': 'North Office'},
          {'id': '9', 'name': 'Head Office'},
        ],
      });

      expect(user.locations[0].isDefault, isFalse);
      expect(user.locations[1].isDefault, isTrue);
    });

    test('does not use location_id as the manager default', () {
      final user = AuthUserModel.fromJson({
        'id': 1,
        'name': 'Ava',
        'email': 'ava@example.com',
        'location_id': '5',
        'locations': [
          {'id': '5', 'name': 'North Office'},
          {'id': '9', 'name': 'Head Office', 'is_default': true},
        ],
      });

      expect(user.locations[0].isDefault, isFalse);
      expect(user.locations[1].isDefault, isTrue);
    });
  });
}
