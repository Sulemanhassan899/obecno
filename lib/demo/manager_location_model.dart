export 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';

import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';

final List<ManagerLocationModel> dummyManagerLocations = [
  const ManagerLocationModel(
    id: 'head',
    name: 'Head Office',
    address: 'Bailey St, Stafford ST17 4BG, Birmingham',
    present: 33,
    total: 40,
    lateCheckIns: 10,
  ),
  const ManagerLocationModel(
    id: 'north',
    name: 'North Office',
    address: 'Bailey St, Stafford ST17 4BG, Stafford',
    present: 20,
    total: 22,
    lateCheckIns: 4,
  ),
  const ManagerLocationModel(
    id: 'south',
    name: 'South Office',
    address: 'Bailey St, Stafford ST17 4BG, London',
    present: 19,
    total: 24,
    lateCheckIns: 8,
  ),
  const ManagerLocationModel(
    id: 'distribution',
    name: 'Distribution Center',
    address: 'Bailey St, Stafford ST17 4BG, Birmingham',
    present: 10,
    total: 10,
    lateCheckIns: 1,
  ),
];
