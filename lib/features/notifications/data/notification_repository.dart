import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<List<AppNotification>> watchForUser(String uid) {
    return _notifications
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    AppNotification.fromMap(document.id, document.data()),
              )
              .toList(growable: false),
        );
  }

  Future<bool> createInterestOnce({
    required String fromUid,
    required String toUid,
  }) async {
    if (fromUid == toUid) {
      throw ArgumentError('A user cannot express interest in themselves.');
    }

    final interestEdge = _firestore
        .collection('users')
        .doc(fromUid)
        .collection('interests')
        .doc(toUid);
    return _firestore.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(interestEdge);
      if (existing.exists) return false;

      transaction.set(interestEdge, {
        'uid': toUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<void> markRead(String notificationId) =>
      _notifications.doc(notificationId).update({'read': true});

  Future<void> delete(String notificationId) =>
      _notifications.doc(notificationId).delete();
}
