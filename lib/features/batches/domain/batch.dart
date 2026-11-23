import 'package:cloud_firestore/cloud_firestore.dart';

enum BatchStatus {
  active,
  completed;

  static BatchStatus fromValue(Object? value) {
    return BatchStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw FormatException('Unsupported batch status: $value'),
    );
  }
}

class Batch {
  Batch({
    required this.id,
    required this.teacherUid,
    required List<String> studentUids,
    required this.projectId,
    required this.startDate,
    required this.endDate,
    required this.status,
  }) : studentUids = List.unmodifiable(studentUids) {
    if (studentUids.length < 4) {
      throw ArgumentError('A batch must include at least four students.');
    }
    if (studentUids.toSet().length != studentUids.length) {
      throw ArgumentError('A batch cannot contain duplicate students.');
    }
    if (endDate != addThreeMonths(startDate)) {
      throw ArgumentError(
          'Batch endDate must be three months after startDate.');
    }
  }

  final String id;
  final String teacherUid;
  final List<String> studentUids;
  final String projectId;
  final DateTime startDate;
  final DateTime endDate;
  final BatchStatus status;

  factory Batch.fromMap(String id, Map<String, dynamic> map) {
    final students = map['studentUids'];
    final startDate = map['startDate'];
    final endDate = map['endDate'];
    if (students is! List || students.any((value) => value is! String)) {
      throw const FormatException('Missing or invalid studentUids.');
    }
    if ((startDate is! Timestamp && startDate is! DateTime) ||
        (endDate is! Timestamp && endDate is! DateTime)) {
      throw const FormatException('Missing or invalid batch dates.');
    }
    return Batch(
      id: id,
      teacherUid: _string(map, 'teacherUid'),
      studentUids: students.cast<String>(),
      projectId: _string(map, 'projectId'),
      startDate: startDate is Timestamp ? startDate.toDate() : startDate,
      endDate: endDate is Timestamp ? endDate.toDate() : endDate,
      status: BatchStatus.fromValue(map['status']),
    );
  }

  Map<String, dynamic> toMap() => {
        'teacherUid': teacherUid,
        'studentUids': studentUids,
        'projectId': projectId,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': status.name,
      };

  static DateTime addThreeMonths(DateTime date) {
    final month = date.month + 3;
    final year = date.year + ((month - 1) ~/ 12);
    final normalizedMonth = ((month - 1) % 12) + 1;
    final lastDay = DateTime(year, normalizedMonth + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    if (date.isUtc) {
      return DateTime.utc(
        year,
        normalizedMonth,
        day,
        date.hour,
        date.minute,
        date.second,
        date.millisecond,
        date.microsecond,
      );
    }
    return DateTime(
      year,
      normalizedMonth,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('Missing or invalid $key.');
    return value;
  }
}
