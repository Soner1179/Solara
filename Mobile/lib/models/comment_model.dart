import 'package:intl/intl.dart'; // Import for date parsing

class Comment {
  final int id;
  final int postId;
  final int userId;
  final String commentText;
  final int? parentCommentId; // Added for replies
  final DateTime createdAt;
  final String username; // Assuming username is included in the fetched data
  final String? profilePictureUrl; // Assuming profile picture URL is included
  int likeCount; // Added for comment likes
  bool isLiked; // Added to track if the current user liked the comment

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.commentText,
    this.parentCommentId,
    required this.createdAt,
    required this.username,
    this.profilePictureUrl,
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['comment_id'], // Corrected to use 'comment_id' from JSON
      postId: json['post_id'],
      userId: json['user_id'],
      commentText: json['comment_text'],
      parentCommentId: json['parent_comment_id'],
      createdAt: DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'").parse(json['created_at'], true).toLocal(), // Parse using DateFormat
      username: json['username'],
      profilePictureUrl: json['profile_picture_url'],
      likeCount: json['like_count'] ?? 0, // Assuming like_count is provided by API, default to 0 if null
      isLiked: json['is_liked'] ?? false, // Assuming is_liked is provided by API, default to false if null
    );
  }
}
