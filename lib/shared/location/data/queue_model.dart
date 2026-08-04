import 'package:Obecno/shared/location/service/attendance_payload_model.dart';

class QueueModel {
  final int id;
  final AttendancePayloadModel payload;
  final bool isSynced;

  const QueueModel({
    required this.id,
    required this.payload,
    required this.isSynced,
  });

  factory QueueModel.fromMap(Map<String, dynamic> map) {
    return QueueModel(
      id: map['id'] as int,
      isSynced: (map['is_synced'] as int) == 1,
      payload: AttendancePayloadModel.fromQueueMap(map),
    );
  }
}
