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

  Future<void> create(AppNotification notification) =>
      _notifications.doc(notification.id).set(notification.toMap());

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
    final notificationId = 'interest_${fromUid}_$toUid';
    final notification = _notifications.doc(notificationId);

    return _firestore.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(interestEdge);
      if (existing.exists) return false;

      final createdAt = DateTime.now();
      transaction.set(interestEdge, {
        'uid': toUid,
        'createdAt': Timestamp.fromDate(createdAt),
      });
      transaction.set(notification, {
        'toUid': toUid,
        'fromUid': fromUid,
        'type': NotificationType.interest.wireValue,
        'refId': fromUid,
        'createdAt': Timestamp.fromDate(createdAt),
        'read': false,
      });
      return true;
    });
  }

  Future<void> markRead(String notificationId) =>
      _notifications.doc(notificationId).update({'read': true});

  Future<void> delete(String notificationId) =>
      _notifications.doc(notificationId).delete();
}
