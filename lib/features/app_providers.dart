import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'batches/data/batch_repository.dart';
import 'batches/domain/batch.dart';
import 'batches/domain/batch_message.dart';
import 'batches/domain/batch_task.dart';
import 'notifications/data/notification_repository.dart';
import 'notifications/domain/app_notification.dart';
import 'posts/data/post_repository.dart';
import 'posts/domain/post.dart';
import 'projects/data/project_repository.dart';
import 'projects/domain/project.dart';
import 'users/data/user_repository.dart';
import 'users/domain/user_profile.dart';
import 'ai/data/ai_repository.dart';
import 'ai/domain/teammate_suggestion.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firebaseStorageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
final firebaseMessagingProvider =
    Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);
final firebaseFunctionsProvider =
    Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instance);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  ),
);
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(firestoreProvider)),
);
final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(ref.watch(firestoreProvider)),
);
final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(firestoreProvider)),
);
final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => AiRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  ),
);
final teammateSuggestionsProvider =
    FutureProvider.family<List<TeammateSuggestion>, TeamSuggestionRequest>(
  (ref, request) => ref.watch(aiRepositoryProvider).suggestTeammates(
        uid: request.uid,
        projectId: request.projectId,
      ),
);
final aiChatMessagesProvider =
    StreamProvider.family<List<AiChatMessage>, String>(
  (ref, uid) => ref.watch(aiRepositoryProvider).watchChat(uid),
);
final batchRepositoryProvider = Provider<BatchRepository>(
  (ref) => BatchRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  ),
);

final userProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchByUid(uid);
});
final userDirectoryProvider = StreamProvider<List<UserProfile>>(
  (ref) => ref.watch(userRepositoryProvider).watchProfiles(),
);
final facultyGuidedStudentCountProvider =
    StreamProvider.family<int, String>((ref, teacherUid) {
  return ref
      .watch(firestoreProvider)
      .collection('facultyStats')
      .doc(teacherUid)
      .snapshots()
      .map((snapshot) {
    final students = snapshot.data()?['activeStudentUids'];
    if (students is! List) return 0;
    return students.whereType<String>().toSet().length;
  });
});
final followingUidsProvider = StreamProvider.family<List<String>, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).watchFollowingUids(uid),
);
final isFollowingProvider = StreamProvider.family<bool, FollowPair>(
  (ref, ids) => ref.watch(userRepositoryProvider).watchFollowing(
        ids.followerUid,
        ids.targetUid,
      ),
);
final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, uid) {
  return ref.watch(notificationRepositoryProvider).watchForUser(uid);
});
final unreadNotificationsProvider =
    StreamProvider.family<int, String>((ref, uid) {
  return ref
      .watch(notificationRepositoryProvider)
      .watchForUser(uid)
      .map((items) => items.where((item) => !item.read).length);
});
final postFeedProvider = StreamProvider<List<Post>>(
  (ref) => ref.watch(postRepositoryProvider).watchFeed(),
);
final authorPostsProvider =
    StreamProvider.family<List<Post>, String>((ref, uid) {
  return ref.watch(postRepositoryProvider).watchByAuthor(uid);
});
final projectFeedProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).watchProjects(),
);
final userBatchesProvider =
    StreamProvider.family<List<Batch>, String>((ref, uid) {
  return ref.watch(batchRepositoryProvider).watchForUser(uid);
});
final teacherBatchesProvider =
    StreamProvider.family<List<Batch>, String>((ref, uid) {
  return ref.watch(batchRepositoryProvider).watchByTeacher(uid);
});
final batchTasksProvider =
    StreamProvider.family<List<BatchTask>, String>((ref, batchId) {
  return ref.watch(batchRepositoryProvider).watchTasks(batchId);
});
final batchProvider = StreamProvider.family<Batch?, String>(
  (ref, batchId) => ref.watch(batchRepositoryProvider).watchById(batchId),
);
final activeBatchIdProvider = StreamProvider.family<String?, String>(
  (ref, uid) => ref.watch(batchRepositoryProvider).watchActiveBatchId(uid),
);
final batchMessagesProvider = StreamProvider.family<List<BatchMessage>, String>(
  (ref, batchId) => ref.watch(batchRepositoryProvider).watchMessages(batchId),
);

class FollowPair {
  const FollowPair(this.followerUid, this.targetUid);

  final String followerUid;
  final String targetUid;

  @override
  bool operator ==(Object other) =>
      other is FollowPair &&
      other.followerUid == followerUid &&
      other.targetUid == targetUid;

  @override
  int get hashCode => Object.hash(followerUid, targetUid);
}
