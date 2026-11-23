class TeammateSuggestion {
  const TeammateSuggestion({
    required this.uid,
    required this.name,
    required this.role,
    required this.department,
    required this.photoUrl,
    required this.skills,
    required this.interests,
    required this.collegeName,
    required this.experienceLevel,
    required this.availability,
    required this.preferredWorkingHours,
    required this.score,
    required this.reason,
  });

  final String uid;
  final String name;
  final String role;
  final String department;
  final String photoUrl;
  final List<String> skills;
  final List<String> interests;
  final String collegeName;
  final String experienceLevel;
  final String availability;
  final String preferredWorkingHours;
  final int score;
  final String reason;

  factory TeammateSuggestion.fromMap(Map<String, dynamic> map) {
    final skills = map['skills'];
    final interests = map['interests'];
    if (map['uid'] is! String ||
        map['name'] is! String ||
        map['role'] is! String ||
        map['department'] is! String ||
        map['photoUrl'] is! String ||
        skills is! List ||
        skills.any((skill) => skill is! String) ||
        interests is! List ||
        interests.any((interest) => interest is! String) ||
        map['collegeName'] is! String ||
        map['experienceLevel'] is! String ||
        map['availability'] is! String ||
        map['preferredWorkingHours'] is! String ||
        map['score'] is! num ||
        map['reason'] is! String) {
      throw const FormatException('Invalid teammate suggestion.');
    }
    return TeammateSuggestion(
      uid: map['uid'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      department: map['department'] as String,
      photoUrl: map['photoUrl'] as String,
      skills: List.unmodifiable(skills.cast<String>()),
      interests: List.unmodifiable(interests.cast<String>()),
      collegeName: map['collegeName'] as String,
      experienceLevel: map['experienceLevel'] as String,
      availability: map['availability'] as String,
      preferredWorkingHours: map['preferredWorkingHours'] as String,
      score: (map['score'] as num).round(),
      reason: map['reason'] as String,
    );
  }
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
}

class TeamSuggestionRequest {
  const TeamSuggestionRequest({
    required this.uid,
    required this.projectId,
  });

  final String uid;
  final String projectId;

  @override
  bool operator ==(Object other) =>
      other is TeamSuggestionRequest &&
      other.uid == uid &&
      other.projectId == projectId;

  @override
  int get hashCode => Object.hash(uid, projectId);
}
