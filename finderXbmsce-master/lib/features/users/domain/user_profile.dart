import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  student('student'),
  teacher('teacher'),
  innovator('innovator');

  const UserRole(this.value);

  final String value;

  static UserRole fromValue(Object? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => throw FormatException('Unsupported user role: $value'),
    );
  }
}

class UserProfile {
  UserProfile({
    required this.uid,
    required this.role,
    required this.name,
    required this.bio,
    required this.photoUrl,
    required this.department,
    required List<String> skills,
    required List<String> interests,
    required this.followersCount,
    required this.followingCount,
    required this.resumeUrl,
    required this.createdAt,
    List<String> domains = const [],
    List<String> certificationUrls = const [],
  })  : skills = List.unmodifiable(skills),
        interests = List.unmodifiable(interests),
        domains = List.unmodifiable(domains),
        certificationUrls = List.unmodifiable(certificationUrls) {
    if (uid.isEmpty) throw ArgumentError.value(uid, 'uid', 'must not be empty');
    if (followersCount < 0 || followingCount < 0) {
      throw ArgumentError('Follower counts cannot be negative.');
    }
  }

  final String uid;
  final UserRole role;
  final String name;
  final String bio;
  final String photoUrl;
  final String department;
  final List<String> skills;
  final List<String> interests;
  final List<String> domains;
  final List<String> certificationUrls;
  final int followersCount;
  final int followingCount;
  final String? resumeUrl;
  final DateTime createdAt;

  factory UserProfile.fromMap(
    String uid,
    Map<String, dynamic> map,
  ) {
    return UserProfile(
      uid: uid,
      role: UserRole.fromValue(map['role']),
      name: _requiredString(map, 'name'),
      bio: _requiredString(map, 'bio'),
      photoUrl: _requiredString(map, 'photoUrl'),
      department: _requiredString(map, 'department'),
      skills: _stringList(map['skills'], 'skills'),
      interests: _stringList(map['interests'], 'interests'),
      domains: _optionalStringList(map['domains'], 'domains'),
      certificationUrls:
          _optionalStringList(map['certificationUrls'], 'certificationUrls'),
      followersCount: _requiredInt(map, 'followersCount'),
      followingCount: _requiredInt(map, 'followingCount'),
      resumeUrl: map['resumeUrl'] as String?,
      createdAt: _dateTime(map['createdAt'], 'createdAt'),
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role.value,
        'name': name,
        'bio': bio,
        'photoUrl': photoUrl,
        'department': department,
        'skills': skills,
        'interests': interests,
        'domains': domains,
        'certificationUrls': certificationUrls,
        'followersCount': followersCount,
        'followingCount': followingCount,
        'resumeUrl': resumeUrl,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('Missing or invalid $key.');
    return value;
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException('Missing or invalid $key.');
    return value;
  }

  static List<String> _stringList(Object? value, String key) {
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('Missing or invalid $key.');
    }
    return value.cast<String>();
  }

  static List<String> _optionalStringList(Object? value, String key) {
    if (value == null) return const [];
    return _stringList(value, key);
  }

  static DateTime _dateTime(Object? value, String key) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw FormatException('Missing or invalid $key.');
  }
}
