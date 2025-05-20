// lib/models/user_model.dart

class User {
  final int userId;
  final String username;
  final String? fullName;
  final String? profilePictureUrl;
  // Add other fields if needed from your API, e.g., email, is_following, etc.

  User({
    required this.userId,
    required this.username,
    this.fullName,
    this.profilePictureUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as int? ?? 0,
      username: json['username'] as String? ?? 'unknown_user',
      fullName: json['full_name'] as String?, // Can be null
      profilePictureUrl: json['profile_picture_url'] as String?, // Can be null
    );
  }

  // Optional: A method to get a display name, preferring full_name
  String get displayName {
    return fullName != null && fullName!.isNotEmpty ? fullName! : username;
  }
}
