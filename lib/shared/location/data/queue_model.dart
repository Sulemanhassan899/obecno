import 'package:Obecno/shared/location/service/attendance_payload_model.dart';


/// One row read back from the local `attendance_queue` SQLite table --
/// the SQLite-assigned [id] plus the original payload, used by
/// [SyncService] to replay unsynced records FIFO and mark them synced.
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
