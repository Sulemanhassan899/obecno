import 'package:obecno/core/generated/assets.dart';

enum ManagerEmployeeStatus { active, pending, disabled, deleted }

enum ManagerEmployeeBadge { none, owner, manager, you }

class ManagerEmployeeModel {
  const ManagerEmployeeModel({
    required this.id,
    required this.name,
    required this.role,
    this.photo,
    this.locationId,
    this.status = ManagerEmployeeStatus.active,
    this.badge = ManagerEmployeeBadge.none,
  });

  final String id;
  final String name;
  final String role;
  final String? photo;
  final String? locationId;
  final ManagerEmployeeStatus status;
  final ManagerEmployeeBadge badge;

  String get photoPath => photo ?? Assets.imagesUserimage;

  String? get badgeLabel {
    switch (badge) {
      case ManagerEmployeeBadge.owner:
        return 'Owner';
      case ManagerEmployeeBadge.manager:
        return 'Manager';
      case ManagerEmployeeBadge.you:
        return 'You';
      case ManagerEmployeeBadge.none:
        return null;
    }
  }

  String? get statusLabel {
    switch (status) {
      case ManagerEmployeeStatus.pending:
        return 'Pending';
      case ManagerEmployeeStatus.disabled:
        return 'Disabled';
      case ManagerEmployeeStatus.deleted:
        return 'Deleted';
      case ManagerEmployeeStatus.active:
        return null;
    }
  }
}

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
