import 'package:Obecno/core/generated/assets.dart';

class ManagerLocationModel {
  const ManagerLocationModel({
    required this.id,
    required this.name,
    required this.address,
    this.image,
    this.latitude,
    this.longitude,
    this.present = 0,
    this.total = 0,
    this.lateCheckIns = 0,
    this.createdBy = 'Ava Montgomery',
    this.createdAt = '20 Jan 2026',
  });

  final String id;
  final String name;
  final String address;
  final String? image;
  final double? latitude;
  final double? longitude;
  final int present;
  final int total;
  final int lateCheckIns;
  final String createdBy;
  final String createdAt;

  String get imagePath => image ?? Assets.imagesDummyMaps;

  ManagerLocationModel copyWith({
    String? id,
    String? name,
    String? address,
    String? image,
    double? latitude,
    double? longitude,
    int? present,
    int? total,
    int? lateCheckIns,
    String? createdBy,
    String? createdAt,
  }) {
    return ManagerLocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      image: image ?? this.image,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      present: present ?? this.present,
      total: total ?? this.total,
      lateCheckIns: lateCheckIns ?? this.lateCheckIns,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

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
