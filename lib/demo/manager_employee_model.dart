export 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';

import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';

final List<ManagerEmployeeModel> dummyManagerEmployees = [
  const ManagerEmployeeModel(
    id: '1',
    name: 'Ava Montgomery',
    role: 'CEO',
    locationId: 'head',
    badge: ManagerEmployeeBadge.owner,
  ),
  const ManagerEmployeeModel(
    id: '2',
    name: 'Isabella Knight',
    role: 'Supervisor',
    locationId: 'head',
    badge: ManagerEmployeeBadge.manager,
  ),
  const ManagerEmployeeModel(
    id: '3',
    name: 'Sophia Blake',
    role: 'Operations Manager',
    locationId: 'north',
  ),
  const ManagerEmployeeModel(
    id: '4',
    name: 'Mia Harper',
    role: 'Logistics Coordinator',
    locationId: 'south',
    status: ManagerEmployeeStatus.pending,
  ),
  const ManagerEmployeeModel(
    id: '5',
    name: 'Ethan Rivers',
    role: 'Operations Strategist',
    locationId: 'head',
    status: ManagerEmployeeStatus.disabled,
  ),
  const ManagerEmployeeModel(
    id: '6',
    name: 'Lucas Bennett',
    role: 'Operations Chief',
    locationId: 'north',
    status: ManagerEmployeeStatus.deleted,
  ),
  const ManagerEmployeeModel(
    id: '7',
    name: 'Armando Predovic',
    role: 'Director of Operations',
    locationId: 'head',
    badge: ManagerEmployeeBadge.owner,
  ),
  const ManagerEmployeeModel(
    id: '8',
    name: 'Liam Prescott',
    role: 'Director of Operations',
    locationId: 'south',
    badge: ManagerEmployeeBadge.you,
  ),
  const ManagerEmployeeModel(
    id: '9',
    name: 'Oliver Hayes',
    role: 'Operations Head',
    locationId: 'distribution',
  ),
  const ManagerEmployeeModel(
    id: '10',
    name: 'Jackson Cole',
    role: 'Operations Lead',
    locationId: 'north',
  ),
  const ManagerEmployeeModel(
    id: '11',
    name: 'Mason Brooks',
    role: 'Operations Coordinator',
    locationId: 'distribution',
  ),
];
