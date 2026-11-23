import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/post.dart';

class PostRepository {
  PostRepository(this._firestore);

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  Stream<List<Post>> watchFeed() {
    return _posts.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((document) => Post.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  Stream<List<Post>> watchByAuthor(String authorUid) {
    return _posts
        .where('authorUid', isEqualTo: authorUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((document) => Post.fromMap(document.id, document.data()))
            .toList(growable: false));
  }

  Future<PostPage> fetchFollowedPage({
    required Set<String> authorUids,
    required PostCursor? cursor,
    int pageSize = 20,
  }) async {
    if (authorUids.isEmpty) {
      return const PostPage(posts: [], cursor: null, hasMore: false);
    }

    Query<Map<String, dynamic>> query =
        _posts.orderBy('createdAt', descending: true).limit(pageSize);
    if (cursor != null) {
      query = query.startAfterDocument(cursor.document);
    }
    final snapshot = await query.get();
    final posts = snapshot.docs
        .where((document) => authorUids.contains(document['authorUid']))
        .map((document) => Post.fromMap(document.id, document.data()))
        .toList(growable: false);
    return PostPage(
      posts: posts,
      cursor: snapshot.docs.isEmpty ? null : PostCursor(snapshot.docs.last),
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  Stream<List<Post>> watchByAuthors(Set<String> authorUids) {
    if (authorUids.isEmpty) return Stream.value(const []);
    return _posts.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .where((document) => authorUids.contains(document['authorUid']))
              .map((document) => Post.fromMap(document.id, document.data()))
              .toList(growable: false),
        );
  }

  Future<void> create(Post post) => _posts.doc(post.id).set(post.toMap());
}

class PostCursor {
  const PostCursor(this.document);

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
}

class PostPage {
  const PostPage({
    required this.posts,
    required this.cursor,
    required this.hasMore,
  });

  final List<Post> posts;
  final PostCursor? cursor;
  final bool hasMore;
}
