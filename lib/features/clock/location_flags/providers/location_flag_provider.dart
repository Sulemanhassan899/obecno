import 'package:flutter/foundation.dart';
import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_timeline.dart';
import 'package:obecno/features/clock/location_flags/repositories/location_flag_repository.dart';

class LocationFlagProvider extends ChangeNotifier {
  LocationFlagProvider({
    required LocationFlagRepository repository,
    required String? Function() employeeIdProvider,
  }) : _repository = repository,
       _employeeIdProvider = employeeIdProvider;

  final LocationFlagRepository _repository;
  final String? Function() _employeeIdProvider;

  List<LocationFlagRecord> _records = const [];
  List<LocationFlagRecord> get records => _records;

  LocationFlagUiStatus status = LocationFlagUiStatus.notCheckedIn;
  bool requiresServerSync = false;

  Future<void> reloadForDay(DateTime day) async {
    final employeeId = _employeeIdProvider();
    if (employeeId == null || employeeId.isEmpty) {
      _records = const [];
      status = LocationFlagUiStatus.notCheckedIn;
      requiresServerSync = false;
      notifyListeners();
      return;
    }

    _records = await _repository.recordsForDate(
      employeeId: employeeId,
      day: day,
    );
    final observations = _records
        .map(
          (row) => LocationFlagObservation(
            at: row.timestamp,
            inside: row.insideRadius,
            checkInStatus: row.checkInStatus,
            breakStatus: row.breakStatus,
            checkOutStatus: row.checkOutStatus,
            locationStatus: row.locationStatus,
          ),
        )
        .toList();
    final checkedIn = _records.any((row) => row.checkInStatus);
    final verdict = LocationFlagEvaluator.evaluate(
      checkInStatus: checkedIn,
      observations: observations,
    );
    status = verdict.status;
    requiresServerSync = verdict.requiresServerSync;
    notifyListeners();
  }

  List<LocationFlagObservation> get observations => _records
      .map(
        (row) => LocationFlagObservation(
          at: row.timestamp,
          inside: row.insideRadius,
          checkInStatus: row.checkInStatus,
          breakStatus: row.breakStatus,
          checkOutStatus: row.checkOutStatus,
          locationStatus: row.locationStatus,
        ),
      )
      .toList();

  List<LocationOutsideInterval> outsideIntervals() {
    return LocationFlagTimeline.outsideIntervals(observations: observations);
  }
}
