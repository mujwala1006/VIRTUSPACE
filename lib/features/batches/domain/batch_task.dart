import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus {
  todo,
  doing,
  done;

  static TaskStatus fromValue(Object? value) {
    return TaskStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw FormatException('Unsupported task status: $value'),
    );
  }
}

class BatchTask {
  const BatchTask({
    required this.id,
    required this.title,
    required this.description,
    required this.assigneeUid,
    required this.status,
    required this.updatedBy,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String assigneeUid;
  final TaskStatus status;
  final String updatedBy;
  final DateTime updatedAt;

  factory BatchTask.fromMap(String id, Map<String, dynamic> map) {
    final updatedAt = map['updatedAt'];
    if (updatedAt is! Timestamp && updatedAt is! DateTime) {
      throw const FormatException('Missing or invalid updatedAt.');
    }
    return BatchTask(
      id: id,
      title: _string(map, 'title'),
      description: _string(map, 'description'),
      assigneeUid: _string(map, 'assigneeUid'),
      status: TaskStatus.fromValue(map['status']),
      updatedBy: _string(map, 'updatedBy'),
      updatedAt:
          updatedAt is Timestamp ? updatedAt.toDate() : updatedAt as DateTime,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'assigneeUid': assigneeUid,
        'status': status.name,
        'updatedBy': updatedBy,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('Missing or invalid $key.');
    return value;
  }
}
