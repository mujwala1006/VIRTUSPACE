import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType {
  update,
  certification;

  static PostType fromValue(Object? value) {
    return PostType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => throw FormatException('Unsupported post type: $value'),
    );
  }
}

class Post {
  Post({
    required this.id,
    required this.authorUid,
    required this.type,
    required this.text,
    required List<String> imageUrls,
    required this.createdAt,
    required this.likesCount,
  }) : imageUrls = List.unmodifiable(imageUrls) {
    if (likesCount < 0) throw ArgumentError('likesCount cannot be negative.');
  }

  final String id;
  final String authorUid;
  final PostType type;
  final String text;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likesCount;

  factory Post.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    final imageUrls = map['imageUrls'];
    if (createdAt is! Timestamp && createdAt is! DateTime) {
      throw const FormatException('Missing or invalid createdAt.');
    }
    if (imageUrls is! List || imageUrls.any((item) => item is! String)) {
      throw const FormatException('Missing or invalid imageUrls.');
    }
    final likesCount = map['likesCount'];
    if (likesCount is! int) {
      throw const FormatException('Missing or invalid likesCount.');
    }
    return Post(
      id: id,
      authorUid: _string(map, 'authorUid'),
      type: PostType.fromValue(map['type']),
      text: _string(map, 'text'),
      imageUrls: imageUrls.cast<String>(),
      createdAt:
          createdAt is Timestamp ? createdAt.toDate() : createdAt as DateTime,
      likesCount: likesCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'type': type.name,
        'text': text,
        'imageUrls': imageUrls,
        'createdAt': Timestamp.fromDate(createdAt),
        'likesCount': likesCount,
      };

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('Missing or invalid $key.');
    return value;
  }
}
