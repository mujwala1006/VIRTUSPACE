import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  Project({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.description,
    required List<String> domains,
    required List<String> requiredSkills,
    required this.status,
    required this.batchId,
    required this.createdAt,
    this.doneTaskCount = 0,
    this.totalTaskCount = 0,
  })  : domains = List.unmodifiable(domains),
        requiredSkills = List.unmodifiable(requiredSkills) {
    if (title.trim().isEmpty) throw ArgumentError('title cannot be empty.');
    if (status.trim().isEmpty) throw ArgumentError('status cannot be empty.');
    if (doneTaskCount < 0 ||
        totalTaskCount < 0 ||
        doneTaskCount > totalTaskCount) {
      throw ArgumentError('Project task counts are invalid.');
    }
  }

  final String id;
  final String ownerUid;
  final String title;
  final String description;
  final List<String> domains;
  final List<String> requiredSkills;
  final String status;
  final String? batchId;
  final DateTime createdAt;
  final int doneTaskCount;
  final int totalTaskCount;

  factory Project.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    if (createdAt is! Timestamp && createdAt is! DateTime) {
      throw const FormatException('Missing or invalid createdAt.');
    }
    return Project(
      id: id,
      ownerUid: _string(map, 'ownerUid'),
      title: _string(map, 'title'),
      description: _string(map, 'description'),
      domains: _strings(map, 'domains'),
      requiredSkills: _strings(map, 'requiredSkills'),
      status: _string(map, 'status'),
      batchId: map['batchId'] as String?,
      createdAt:
          createdAt is Timestamp ? createdAt.toDate() : createdAt as DateTime,
      doneTaskCount: map['doneTaskCount'] as int? ?? 0,
      totalTaskCount: map['totalTaskCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'title': title,
        'description': description,
        'domains': domains,
        'requiredSkills': requiredSkills,
        'status': status,
        'batchId': batchId,
        'createdAt': Timestamp.fromDate(createdAt),
        'doneTaskCount': doneTaskCount,
        'totalTaskCount': totalTaskCount,
      };

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('Missing or invalid $key.');
    return value;
  }

  static List<String> _strings(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('Missing or invalid $key.');
    }
    return value.cast<String>();
  }
}
