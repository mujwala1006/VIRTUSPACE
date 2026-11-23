import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/batch.dart';
import '../domain/batch_task.dart';
import '../domain/batch_message.dart';

class BatchRepository {
  BatchRepository(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  CollectionReference<Map<String, dynamic>> get _batches =>
      _firestore.collection('batches');
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<Batch?> watchById(String batchId) {
    return _batches.doc(batchId).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : Batch.fromMap(snapshot.id, data);
    });
  }

  Stream<String?> watchActiveBatchId(String uid) {
    return _users
        .doc(uid)
        .collection('activeBatch')
        .doc('current')
        .snapshots()
        .map((snapshot) => snapshot.data()?['batchId'] as String?);
  }

  Stream<List<Batch>> watchForUser(String uid) {
    return _batches.where('studentUids', arrayContains: uid).snapshots().map(
        (snapshot) => snapshot.docs
            .map((document) => Batch.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  Stream<List<Batch>> watchByTeacher(String teacherUid) {
    return _batches.where('teacherUid', isEqualTo: teacherUid).snapshots().map(
        (snapshot) => snapshot.docs
            .map((document) => Batch.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  Future<void> create(Batch batch) async {
    await _functions.httpsCallable('createBatch').call({
      'batchId': batch.id,
      'projectId': batch.projectId,
      'studentUids': batch.studentUids,
    });
  }

  Stream<List<BatchTask>> watchTasks(String batchId) {
    return _batches
        .doc(batchId)
        .collection('tasks')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((document) => BatchTask.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  Future<void> createTask(String batchId, BatchTask task) =>
      _batches.doc(batchId).collection('tasks').doc(task.id).set({
        ...task.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateTask(String batchId, BatchTask task) =>
      _batches.doc(batchId).collection('tasks').doc(task.id).update({
        ...task.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<BatchMessage>> watchMessages(String batchId) {
    return _batches
        .doc(batchId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((document) =>
                BatchMessage.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  Future<void> sendMessage({
    required String batchId,
    required String senderUid,
    required String text,
  }) async {
    final content = text.trim();
    if (content.isEmpty) throw ArgumentError('Message cannot be empty.');
    final message = _batches.doc(batchId).collection('messages').doc();
    await message.set({
      'senderUid': senderUid,
      'text': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
