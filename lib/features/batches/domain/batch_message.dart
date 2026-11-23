import 'package:cloud_firestore/cloud_firestore.dart';

class BatchMessage {
  const BatchMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderUid;
  final String text;
  final DateTime createdAt;

  factory BatchMessage.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    if (createdAt is! Timestamp && createdAt is! DateTime) {
      throw const FormatException('Missing or invalid message createdAt.');
    }
    final senderUid = map['senderUid'];
    final text = map['text'];
    if (senderUid is! String || text is! String) {
      throw const FormatException('Missing or invalid message content.');
    }
    return BatchMessage(
      id: id,
      senderUid: senderUid,
      text: text,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : createdAt,
    );
  }
}
