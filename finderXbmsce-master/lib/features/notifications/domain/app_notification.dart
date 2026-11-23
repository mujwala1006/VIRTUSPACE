import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  follow('follow'),
  interest('interest'),
  batchInvite('batch_invite'),
  teammateInvite('teammate_invite'),
  task('task'),
  batchCompleted('batch_completed'),
  collaborationResponse('collaboration_response');

  const NotificationType(this.wireValue);

  final String wireValue;

  static NotificationType fromValue(Object? value) {
    return NotificationType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () =>
          throw FormatException('Unsupported notification type: $value'),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.toUid,
    required this.fromUid,
    required this.type,
    required this.refId,
    required this.createdAt,
    required this.read,
    this.requestId,
    this.projectId,
    this.projectTitle,
    this.status,
  });

  final String id;
  final String toUid;
  final String fromUid;
  final NotificationType type;
  final String? refId;
  final DateTime createdAt;
  final bool read;
  final String? requestId;
  final String? projectId;
  final String? projectTitle;
  final String? status;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    if (createdAt is! Timestamp && createdAt is! DateTime) {
      throw const FormatException('Missing or invalid createdAt.');
    }
    return AppNotification(
      id: id,
      toUid: _string(map, 'toUid'),
      fromUid: _string(map, 'fromUid'),
      type: NotificationType.fromValue(map['type']),
      refId: map['refId'] as String?,
      createdAt:
          createdAt is Timestamp ? createdAt.toDate() : createdAt as DateTime,
      read: map['read'] as bool? ??
          (throw const FormatException('Missing or invalid read.')),
      requestId: map['requestId'] as String?,
      projectId: map['projectId'] as String?,
      projectTitle: map['projectTitle'] as String?,
      status: map['status'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'toUid': toUid,
        'fromUid': fromUid,
        'type': type.wireValue,
        'refId': refId,
        'createdAt': Timestamp.fromDate(createdAt),
        'read': read,
        if (requestId != null) 'requestId': requestId,
        if (projectId != null) 'projectId': projectId,
        if (projectTitle != null) 'projectTitle': projectTitle,
        if (status != null) 'status': status,
      };

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('Missing or invalid $key.');
    return value;
  }
}
