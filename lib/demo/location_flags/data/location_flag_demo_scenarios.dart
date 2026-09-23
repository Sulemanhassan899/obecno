import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';

class LocationFlagDemoScenario {
  const LocationFlagDemoScenario({
    required this.id,
    required this.label,
    required this.builder,
  });

  final String id;
  final String label;
  final List<LocationFlagObservation> Function(PolicyDayWindow window)
  builder;
}

class LocationFlagDemoScenarios {
  LocationFlagDemoScenarios._();

  static final List<LocationFlagDemoScenario> all = [
    LocationFlagDemoScenario(
      id: 'default_day',
      label: 'Default day',
      builder: defaultWorkingDay,
    ),
    LocationFlagDemoScenario(
      id: 'all_true',
      label: 'ALL TRUE',
      builder: allTrue,
    ),
    LocationFlagDemoScenario(
      id: 'all_false',
      label: 'ALL FALSE',
      builder: allFalse,
    ),
    LocationFlagDemoScenario(
      id: 'mixed_ttf_t',
      label: 'TRUE TRUE FALSE TRUE',
      builder: (window) => mixedHour(window, const [true, true, false, true]),
    ),
    LocationFlagDemoScenario(
      id: 'mixed_tf_tt',
      label: 'TRUE FALSE TRUE TRUE',
      builder: (window) => mixedHour(window, const [true, false, true, true]),
    ),
    LocationFlagDemoScenario(
      id: 'mixed_f_ttt',
      label: 'FALSE TRUE TRUE TRUE',
      builder: (window) => mixedHour(window, const [false, true, true, true]),
    ),
    LocationFlagDemoScenario(
      id: 'not_checked_in',
      label: 'Not checked in',
      builder: notCheckedIn,
    ),
    LocationFlagDemoScenario(
      id: 'gps_unavailable',
      label: 'GPS unavailable',
      builder: gpsUnavailable,
    ),
    LocationFlagDemoScenario(
      id: 'multiple_outside',
      label: 'Multiple outside',
      builder: multipleOutside,
    ),
    LocationFlagDemoScenario(
      id: 'with_break',
      label: 'Break in cycle',
      builder: breakInCycle,
    ),
  ];

  static LocationFlagDemoScenario byId(String id) {
    return all.firstWhere((s) => s.id == id, orElse: () => all.first);
  }

  static List<LocationFlagObservation> defaultWorkingDay(
    PolicyDayWindow window,
  ) {
    return _fill(
      window,
      (at) {
        final tod = at.hour * 60 + at.minute;

        if (tod >= 13 * 60 && tod < 14 * 60) {
          return _obs(at, inside: true, onBreak: true);
        }

        if (tod >= 10 * 60 + 30 && tod < 11 * 60 + 15) {
          return _obs(at, inside: false);
        }
        if (tod >= 14 * 60 && tod < 14 * 60 + 30) {
          return _obs(at, inside: false);
        }
        return _obs(at, inside: true);
      },
      until: window.end,
    );
  }

  static List<LocationFlagObservation> allTrue(PolicyDayWindow window) {
    return _fill(window, (at) => _obs(at, inside: true));
  }

  static List<LocationFlagObservation> allFalse(PolicyDayWindow window) {
    return _fill(window, (at) => _obs(at, inside: false));
  }

  static List<LocationFlagObservation> mixedHour(
    PolicyDayWindow window,
    List<bool> hourFlags,
  ) {
    return _fill(window, (at) {
      if (at.hour != window.start.hour) {
        return _obs(at, inside: true);
      }
      final index = LocationFlagEvaluator.flagNumberFor(at) - 1;
      if (index < 0 || index >= hourFlags.length) {
        return _obs(at, inside: true);
      }
      return _obs(at, inside: hourFlags[index]);
    });
  }

  static List<LocationFlagObservation> notCheckedIn(PolicyDayWindow window) {
    return _fill(
      window,
      (at) => _obs(at, inside: false, checkedIn: false),
    );
  }

  static List<LocationFlagObservation> gpsUnavailable(PolicyDayWindow window) {
    return _fill(window, (at) {
      final flag = LocationFlagEvaluator.flagNumberFor(at);
      if (flag == 2) {
        return _obs(
          at,
          inside: null,
          status: LocationCaptureStatus.unavailable,
        );
      }
      return _obs(at, inside: true);
    });
  }

  static List<LocationFlagObservation> multipleOutside(
    PolicyDayWindow window,
  ) {
    return _fill(window, (at) {
      final tod = at.hour * 60 + at.minute;
      if (tod >= 10 * 60 + 30 && tod < 10 * 60 + 45) {
        return _obs(at, inside: false);
      }
      if (tod >= 12 * 60 && tod < 12 * 60 + 30) {
        return _obs(at, inside: false);
      }
      if (tod >= 15 * 60 && tod < 15 * 60 + 15) {
        return _obs(at, inside: false);
      }
      return _obs(at, inside: true);
    });
  }

  static List<LocationFlagObservation> breakInCycle(PolicyDayWindow window) {
    return _fill(window, (at) {
      final tod = at.hour * 60 + at.minute;
      if (tod >= 13 * 60 && tod < 14 * 60) {
        final inside = tod < 13 * 60 + 30;
        return _obs(at, inside: inside, onBreak: tod >= 13 * 60 + 30);
      }
      return _obs(at, inside: true);
    });
  }

  static List<LocationFlagObservation> _fill(
    PolicyDayWindow window,
    LocationFlagObservation Function(DateTime at) build, {
    DateTime? until,
  }) {
    final end = until ?? window.end;
    final out = <LocationFlagObservation>[];
    var cursor = window.start;
    while (cursor.isBefore(end)) {
      out.add(build(cursor));
      cursor = cursor.add(LocationFlagEvaluator.flagInterval);
    }
    return out;
  }

  static LocationFlagObservation _obs(
    DateTime at, {
    required bool? inside,
    bool checkedIn = true,
    bool onBreak = false,
    bool checkedOut = false,
    LocationCaptureStatus status = LocationCaptureStatus.available,
  }) {
    return LocationFlagObservation(
      at: at,
      inside: checkedIn ? inside : null,
      checkInStatus: checkedIn,
      breakStatus: onBreak,
      checkOutStatus: checkedOut,
      locationStatus: status,
    );
  }
}
