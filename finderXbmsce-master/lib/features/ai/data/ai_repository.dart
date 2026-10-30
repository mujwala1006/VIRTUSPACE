import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/teammate_suggestion.dart';

class AiRepository {
  AiRepository(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<List<TeammateSuggestion>> suggestTeammates({
    required String uid,
    required String projectId,
  }) async {
    final result = await _functions.httpsCallable('suggestTeammates').call({
      'uid': uid,
      'projectId': projectId,
    });
    final data = result.data;
    if (data is! Map || data['suggestions'] is! List) {
      throw const FormatException('Invalid teammate suggestions response.');
    }
    return (data['suggestions'] as List).map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid teammate suggestion.');
      }
      return TeammateSuggestion.fromMap(
        Map<String, dynamic>.from(item),
      );
    }).toList(growable: false);
  }

  Future<bool> inviteTeammate({
    required String toUid,
    required String projectId,
  }) async {
    final result = await _functions.httpsCallable('inviteTeammate').call({
      'toUid': toUid,
      'projectId': projectId,
    });
    final data = result.data;
    if (data is! Map || data['sent'] is! bool) {
      throw const FormatException('Invalid teammate invitation response.');
    }
    return data['sent'] as bool;
  }

  Stream<List<AiChatMessage>> watchChat(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('aiChatMessages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((document) {
              final data = document.data();
              final role = data['role'];
              final content = data['content'];
              final createdAt = data['createdAt'];
              if ((role != 'user' && role != 'assistant') ||
                  content is! String ||
                  createdAt is! Timestamp) {
                throw const FormatException('Invalid AI chat message.');
              }
              return AiChatMessage(
                id: document.id,
                role: role as String,
                content: content,
                createdAt: createdAt.toDate(),
              );
            }).toList(growable: false));
  }

  Future<String> sendChatMessage(String message) async {
    final result = await _functions.httpsCallable('chatbot').call({
      'message': message,
    });
    final data = result.data;
    if (data is! Map || data['answer'] is! String) {
      throw const FormatException('Invalid chatbot response.');
    }
    return data['answer'] as String;
  }
}
