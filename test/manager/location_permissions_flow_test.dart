import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/services/network_checker.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/features/auth/data/models/auth_company_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/repositories/manager_locations_repository.dart';
import 'package:obecno/features/manager_module/Manager_locations/services/manager_locations_service.dart';

class _AlwaysOnline implements NetworkChecker {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class _RecordedCall {
  _RecordedCall({
    required this.method,
    required this.path,
    this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic>? body;
}

/// In-memory manager locations + permissions API.
class _FakeLocationApi extends http.BaseClient {
  final calls = <_RecordedCall>[];
  final locations = <String, Map<String, dynamic>>{};
  final permissions = <String, Map<String, dynamic>>{};
  int _nextId = 1;

  List<_RecordedCall> of(String method, String pathContains) {
    return [
      for (final call in calls)
        if (call.method == method && call.path.contains(pathContains)) call,
    ];
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method.toUpperCase();
    final path = _stripVersion(request.url.path);
    Map<String, dynamic>? body;
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    }
    calls.add(_RecordedCall(method: method, path: path, body: body));

    final replied = _handle(method, path, body);
    final encoded = utf8.encode(jsonEncode(replied.body));
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([encoded]),
      replied.status,
      headers: const {'content-type': 'application/json'},
    );
  }

  String _stripVersion(String path) {
    const prefix = '/api/v1';
    if (path.startsWith(prefix)) return path.substring(prefix.length);
    return path;
  }

  ({int status, Map<String, dynamic> body}) _handle(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) {
    final locationMatch = RegExp(r'^/manager/locations/([^/]+)$').firstMatch(path);
    final permissionsMatch = RegExp(
      r'^/manager/locations/([^/]+)/permissions?$',
    ).firstMatch(path);
    final scheduleMatch = RegExp(
      r'^/manager/locations/([^/]+)/schedule$',
    ).firstMatch(path);

    if (method == 'GET' && path == '/manager/locations') {
      return (
        status: 200,
        body: {
          'success': true,
          'data': {'locations': locations.values.toList()},
        },
      );
    }

    if (method == 'POST' && path == '/manager/locations') {
      final id = '${_nextId++}';
      final created = {
        'id': int.tryParse(id) ?? id,
        'name': body?['name'] ?? 'Office',
        'address': body?['address'],
        'latitude': body?['latitude'],
        'longitude': body?['longitude'],
        'timezone_id': body?['timezone_id'] ?? 8,
        'timezone': body?['timezone'] ?? 'Europe/London',
      };
      locations[id] = created;
      return (status: 201, body: {'success': true, 'data': created});
    }

    if (method == 'GET' && locationMatch != null) {
      final id = locationMatch.group(1)!;
      final location = locations[id];
      if (location == null) {
        return (status: 404, body: {'success': false, 'message': 'Not found'});
      }
      return (status: 200, body: {'success': true, 'data': location});
    }

    if (method == 'GET' && scheduleMatch != null) {
      return (status: 404, body: {'success': false, 'message': 'No schedule'});
    }

    if (permissionsMatch != null) {
      final id = permissionsMatch.group(1)!;
      if (method == 'GET') {
        final stored = permissions[id];
        if (stored == null) {
          return (
            status: 404,
            body: {'success': false, 'message': 'No permissions'},
          );
        }
        return (status: 200, body: {'success': true, 'data': stored});
      }
      if (method == 'PUT') {
        permissions[id] = {
          'location_id': int.tryParse(id) ?? id,
          ...?body,
        };
        return (status: 200, body: {'success': true, 'data': permissions[id]});
      }
      if (method == 'PATCH') {
        final current = Map<String, dynamic>.from(permissions[id] ?? {});
        final currentSetting = Map<String, dynamic>.from(
          current['location_setting'] as Map? ?? const {},
        );
        final incoming = body?['location_setting'];
        if (incoming is Map) {
          currentSetting.addAll(Map<String, dynamic>.from(incoming));
        }
        permissions[id] = {
          ...current,
          ...?body,
          'location_id': int.tryParse(id) ?? id,
          'location_setting': currentSetting,
        };
        return (status: 200, body: {'success': true, 'data': permissions[id]});
      }
    }

    if (method == 'GET' &&
        (path == '/timezones' ||
            path == '/manager/timezones' ||
            path == '/manager/locations/create')) {
      return (
        status: 200,
        body: {
          'success': true,
          'data': {
            'timezones': [
              {'id': 8, 'name': 'Europe/London'},
            ],
          },
        },
      );
    }

    return (
      status: 404,
      body: {'success': false, 'message': 'Unhandled $method $path'},
    );
  }
}

const _seedSchedule = LocationSchedule(
  checkIn: TimeOfDay(hour: 9, minute: 0),
  checkOut: TimeOfDay(hour: 18, minute: 0),
  graceMinutes: 10,
  workingDays: {
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  },
  weekStartDay: 'Monday',
  hoursPerDay: '08:00',
  hoursPerWeek: '40:00',
  workingWeekEnabled: true,
  maxBreakMinutes: 45,
  breakLocationTracking: true,
);

ManagerLocationsService _service(_FakeLocationApi api) {
  final client = ApiClient(
    networkChecker: _AlwaysOnline(),
    tokenService: TokenService(),
    httpClient: api,
    baseUrl: 'https://app.obecno.com/',
  );
  return ManagerLocationsService(
    ManagerLocationsRepository(client),
    companyProvider: () => const AuthCompanyModel(
      id: '1',
      name: 'Obecno',
      cityName: 'Birmingham',
      countryName: 'United Kingdom',
      timezone: 'Europe/London',
      timezoneId: 8,
    ),
    companyScheduleProvider: () async => _seedSchedule,
  );
}

void _expectTimes(
  LocationSchedule schedule, {
  required TimeOfDay checkIn,
  required TimeOfDay checkOut,
  required int grace,
  required int breakMinutes,
  required Set<String> days,
}) {
  expect(schedule.checkIn, checkIn);
  expect(schedule.checkOut, checkOut);
  expect(schedule.graceMinutes, grace);
  expect(schedule.maxBreakMinutes, breakMinutes);
  expect(schedule.workingDays, days);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Test 1 — add location then PUT permissions (full flow)', () {
    test('creates the location then writes every permission with PUT', () async {
      final api = _FakeLocationApi();
      final service = _service(api);

      final created = await service.createLocation(name: 'Head Office');
      expect(created.success, isTrue, reason: created.message);
      expect(created.data?.name, 'Head Office');
      final locationId = created.data!.id;

      expect(api.of('POST', '/manager/locations').length, 1);
      final puts = api.of('PUT', '/permissions');
      expect(puts, isNotEmpty, reason: 'first permission write must be PUT');
      expect(api.of('PATCH', '/permissions'), isEmpty);

      final putBody = puts.first.body!;
      expect(putBody['location_id'], int.tryParse(locationId) ?? locationId);
      expect(putBody['section'], 'attendance');
      expect(putBody['field'], 'check_in_time');
      final setting = putBody['location_setting'] as Map;
      expect(setting['check_in_time'], '09:00');
      expect(setting['check_out_time'], '18:00');
      expect(setting['grace_period'], '10-min');
      expect(setting['break_time'], '45:00 mins');
      expect(setting['working_days'], contains('monday'));

      final loaded = await service.loadLocationSchedule(locationId: locationId);
      expect(loaded.success, isTrue, reason: loaded.message);
      expect(api.of('GET', '/permissions'), isNotEmpty);
      _expectTimes(
        loaded.data!,
        checkIn: const TimeOfDay(hour: 9, minute: 0),
        checkOut: const TimeOfDay(hour: 18, minute: 0),
        grace: 10,
        breakMinutes: 45,
        days: {
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
        },
      );
    });
  });

  group('Test 2 — update all permissions on a location that already has them', () {
    test('uses PATCH and persists the combined new values', () async {
      final api = _FakeLocationApi();
      final service = _service(api);
      final created = await service.createLocation(name: 'Warehouse');
      final locationId = created.data!.id;
      api.calls.clear();

      const next = LocationSchedule(
        checkIn: TimeOfDay(hour: 8, minute: 30),
        checkOut: TimeOfDay(hour: 17, minute: 15),
        graceMinutes: 20,
        workingDays: {'Monday', 'Wednesday', 'Friday'},
        weekStartDay: 'Wednesday',
        hoursPerDay: '07:30',
        hoursPerWeek: '22:30',
        workingWeekEnabled: true,
        maxBreakMinutes: 30,
        breakLocationTracking: false,
      );

      final updated = await service.updateLocationSchedule(
        locationId: locationId,
        schedule: next,
      );
      expect(updated.success, isTrue, reason: updated.message);

      expect(api.of('PUT', '/permissions'), isEmpty);
      final patches = api.of('PATCH', '/permissions');
      expect(patches, isNotEmpty);
      final setting = patches.first.body!['location_setting'] as Map;
      expect(setting['check_in_time'], '08:30');
      expect(setting['check_out_time'], '17:15');
      expect(setting['grace_period'], '20-min');
      expect(setting['break_time'], '30:00 mins');
      expect(setting['break_location_tracking'], isFalse);
      expect(setting['working_days'], unorderedEquals(['monday', 'wednesday', 'friday']));

      final loaded = await service.loadLocationSchedule(locationId: locationId);
      _expectTimes(
        loaded.data!,
        checkIn: const TimeOfDay(hour: 8, minute: 30),
        checkOut: const TimeOfDay(hour: 17, minute: 15),
        grace: 20,
        breakMinutes: 30,
        days: {'Monday', 'Wednesday', 'Friday'},
      );
      expect(loaded.data!.breakLocationTracking, isFalse);
      expect(loaded.data!.weekStartDay, 'Wednesday');
    });
  });

  group('Test 3 — update specific permissions separately and together', () {
    late _FakeLocationApi api;
    late ManagerLocationsService service;
    late String locationId;
    late LocationSchedule current;

    setUp(() async {
      api = _FakeLocationApi();
      service = _service(api);
      final created = await service.createLocation(name: 'Studio');
      locationId = created.data!.id;
      current = (await service.loadLocationSchedule(locationId: locationId)).data!;
      api.calls.clear();
    });

    Future<LocationSchedule> _patch(LocationSchedule next) async {
      final result = await service.updateLocationSchedule(
        locationId: locationId,
        schedule: next,
      );
      expect(result.success, isTrue, reason: result.message);
      expect(api.of('PUT', '/permissions'), isEmpty);
      expect(api.of('PATCH', '/permissions'), isNotEmpty);
      final loaded = await service.loadLocationSchedule(locationId: locationId);
      expect(loaded.success, isTrue, reason: loaded.message);
      current = loaded.data!;
      api.calls.clear();
      return current;
    }

    test('check in only', () async {
      final saved = await _patch(
        current.copyWith(checkIn: const TimeOfDay(hour: 7, minute: 45)),
      );
      expect(saved.checkIn, const TimeOfDay(hour: 7, minute: 45));
      expect(saved.checkOut, const TimeOfDay(hour: 18, minute: 0));
      expect(saved.graceMinutes, 10);
      expect(saved.maxBreakMinutes, 45);
    });

    test('check out only', () async {
      final saved = await _patch(
        current.copyWith(checkOut: const TimeOfDay(hour: 19, minute: 0)),
      );
      expect(saved.checkOut, const TimeOfDay(hour: 19, minute: 0));
      expect(saved.checkIn, const TimeOfDay(hour: 9, minute: 0));
    });

    test('grace period only', () async {
      final saved = await _patch(current.copyWith(graceMinutes: 25));
      expect(saved.graceMinutes, 25);
      expect(saved.checkIn, const TimeOfDay(hour: 9, minute: 0));
    });

    test('break duration only', () async {
      final saved = await _patch(current.copyWith(maxBreakMinutes: 90));
      expect(saved.maxBreakMinutes, 90);
      expect(saved.breakLabel, '90:00 mins');
      expect(saved.checkIn, const TimeOfDay(hour: 9, minute: 0));
      expect(saved.workingDays.contains('Monday'), isTrue);
    });

    test('break location tracking only', () async {
      final saved = await _patch(
        current.copyWith(breakLocationTracking: false),
      );
      expect(saved.breakLocationTracking, isFalse);
      expect(saved.maxBreakMinutes, 45);
    });

    test('working days only', () async {
      final saved = await _patch(
        current.copyWith(workingDays: {'Tuesday', 'Thursday'}),
      );
      expect(saved.workingDays, {'Tuesday', 'Thursday'});
      expect(saved.checkIn, const TimeOfDay(hour: 9, minute: 0));
      expect(saved.maxBreakMinutes, 45);
    });

    test('week start and hours only', () async {
      final saved = await _patch(
        current.copyWith(
          weekStartDay: 'Sunday',
          hoursPerDay: '06:00',
          hoursPerWeek: '30:00',
        ),
      );
      expect(saved.weekStartDay, 'Sunday');
      expect(saved.hoursPerDay, '06:00');
      expect(saved.hoursPerWeek, '30:00');
    });

    test('check in + check out together', () async {
      final saved = await _patch(
        current.copyWith(
          checkIn: const TimeOfDay(hour: 10, minute: 0),
          checkOut: const TimeOfDay(hour: 16, minute: 30),
        ),
      );
      expect(saved.checkIn, const TimeOfDay(hour: 10, minute: 0));
      expect(saved.checkOut, const TimeOfDay(hour: 16, minute: 30));
      expect(saved.maxBreakMinutes, 45);
      expect(saved.workingDays.contains('Friday'), isTrue);
    });

    test('break duration + working days together', () async {
      final saved = await _patch(
        current.copyWith(
          maxBreakMinutes: 15,
          workingDays: {'Monday', 'Saturday'},
        ),
      );
      expect(saved.maxBreakMinutes, 15);
      expect(saved.workingDays, {'Monday', 'Saturday'});
      expect(saved.checkIn, const TimeOfDay(hour: 9, minute: 0));
    });

    test('all timing fields together', () async {
      final saved = await _patch(
        current.copyWith(
          checkIn: const TimeOfDay(hour: 6, minute: 0),
          checkOut: const TimeOfDay(hour: 14, minute: 0),
          graceMinutes: 5,
          maxBreakMinutes: 20,
          breakLocationTracking: false,
          workingDays: {'Monday'},
          weekStartDay: 'Monday',
          hoursPerDay: '08:00',
          hoursPerWeek: '08:00',
        ),
      );
      _expectTimes(
        saved,
        checkIn: const TimeOfDay(hour: 6, minute: 0),
        checkOut: const TimeOfDay(hour: 14, minute: 0),
        grace: 5,
        breakMinutes: 20,
        days: {'Monday'},
      );
      expect(saved.breakLocationTracking, isFalse);
    });

    test('separate edits stack in order: check in, then break, then days', () async {
      await _patch(
        current.copyWith(checkIn: const TimeOfDay(hour: 11, minute: 0)),
      );
      await _patch(current.copyWith(maxBreakMinutes: 12));
      final saved = await _patch(
        current.copyWith(workingDays: {'Friday', 'Sunday'}),
      );

      expect(saved.checkIn, const TimeOfDay(hour: 11, minute: 0));
      expect(saved.maxBreakMinutes, 12);
      expect(saved.workingDays, {'Friday', 'Sunday'});
      expect(saved.checkOut, const TimeOfDay(hour: 18, minute: 0));
      expect(saved.graceMinutes, 10);
    });
  });
}
