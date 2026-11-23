import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_profile.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<UserProfile?> getByUid(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    return data == null ? null : UserProfile.fromMap(snapshot.id, data);
  }

  Stream<UserProfile?> watchByUid(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : UserProfile.fromMap(snapshot.id, data);
    });
  }

  Stream<List<UserProfile>> watchProfiles() {
    return _users.snapshots().map(
          (snapshot) => snapshot.docs
              .map((document) =>
                  UserProfile.fromMap(document.id, document.data()))
              .toList(growable: false),
        );
  }

  Stream<List<String>> watchFollowingUids(String uid) {
    return _users.doc(uid).collection('following').snapshots().map(
          (snapshot) => snapshot.docs
              .map((document) => document.id)
              .toList(growable: false),
        );
  }

  Future<void> create(UserProfile profile) =>
      _users.doc(profile.uid).set(profile.toMap());

  Future<void> updateFields(String uid, Map<String, Object?> fields) =>
      _users.doc(uid).update(fields);

  Future<bool> isFollowing(String followerUid, String targetUid) async {
    final snapshot = await _users
        .doc(followerUid)
        .collection('following')
        .doc(targetUid)
        .get();
    return snapshot.exists;
  }

  Stream<bool> watchFollowing(String followerUid, String targetUid) {
    return _users
        .doc(followerUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<bool> follow(String followerUid, String targetUid) async {
    if (followerUid == targetUid) {
      throw ArgumentError('A user cannot follow themselves.');
    }

    final follower = _users.doc(followerUid);
    final target = _users.doc(targetUid);
    final followingEdge = follower.collection('following').doc(targetUid);
    final followerEdge = target.collection('followers').doc(followerUid);
    final notification = _firestore.collection('notifications').doc();

    return _firestore.runTransaction<bool>((transaction) async {
      final followerSnapshot = await transaction.get(follower);
      final targetSnapshot = await transaction.get(target);
      final followingSnapshot = await transaction.get(followingEdge);
      final followerEdgeSnapshot = await transaction.get(followerEdge);
      if (!followerSnapshot.exists || !targetSnapshot.exists) {
        throw StateError('Both profiles must exist before following.');
      }
      if (followingSnapshot.exists || followerEdgeSnapshot.exists) return false;

      transaction.set(followingEdge, {
        'uid': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(followerEdge, {
        'uid': followerUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notification, {
        'toUid': targetUid,
        'fromUid': followerUid,
        'type': 'follow',
        'refId': targetUid,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'read': false,
      });
      transaction.update(follower, {'followingCount': FieldValue.increment(1)});
      transaction.update(target, {'followersCount': FieldValue.increment(1)});
      return true;
    });
  }

  Future<void> unfollow(String followerUid, String targetUid) async {
    if (followerUid == targetUid) {
      throw ArgumentError('A user cannot unfollow themselves.');
    }

    final follower = _users.doc(followerUid);
    final target = _users.doc(targetUid);
    final followingEdge = follower.collection('following').doc(targetUid);
    final followerEdge = target.collection('followers').doc(followerUid);

    await _firestore.runTransaction((transaction) async {
      final followerSnapshot = await transaction.get(follower);
      final targetSnapshot = await transaction.get(target);
      final followingSnapshot = await transaction.get(followingEdge);
      if (!followerSnapshot.exists || !targetSnapshot.exists) {
        throw StateError('Both profiles must exist before unfollowing.');
      }
      if (!followingSnapshot.exists) return;

      transaction.delete(followingEdge);
      transaction.delete(followerEdge);
      transaction
          .update(follower, {'followingCount': FieldValue.increment(-1)});
      transaction.update(target, {'followersCount': FieldValue.increment(-1)});
    });
  }
}
