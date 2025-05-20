import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solara/constants/api_constants.dart'; // For defaultAvatar and ApiEndpoints
import 'package:solara/services/api_service.dart';
import 'package:solara/services/user_state.dart';
import 'package:solara/models/comment_model.dart'; // Import Comment model

class CommentsPage extends StatefulWidget {
  final int postId;

  const CommentsPage({super.key, required this.postId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final ApiService _apiService = ApiService();
  List<Comment> _comments = []; // Use Comment model
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  int? _replyToCommentId; // Added state for replying
  String? _replyToUsername; // Added state for replying username

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  String _getImageUrl(String? relativeOrAbsoluteUrl) {
    if (relativeOrAbsoluteUrl == null || relativeOrAbsoluteUrl.isEmpty) {
      return defaultAvatar;
    }
    if (relativeOrAbsoluteUrl.startsWith('http')) {
      return relativeOrAbsoluteUrl;
    }
    // Assuming ApiEndpoints.baseUrl is available and correctly configured
    final serverBase = ApiEndpoints.baseUrl.replaceAll('/api', '');
    return '$serverBase$relativeOrAbsoluteUrl';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      final List<dynamic> commentsData = await _apiService.fetchComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _comments = commentsData.map((json) => Comment.fromJson(json)).toList(); // Parse into Comment objects
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching comments: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yorumlar yüklenemedi: ${e.toString()}')));
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _submitComment() async {
    if (!mounted) return;
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yorum boş olamaz.')));
      return;
    }

    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yorum yapmak için giriş yapmalısınız.')));
      // Optionally navigate to login
      return;
    }

    // Optimistic UI update (optional but good for responsiveness)
    // For simplicity here, we'll just refetch comments after successful submission.

    try {
      // Include parentCommentId if replying
      await _apiService.createComment(
        currentUserId,
        widget.postId,
        commentText,
        parentCommentId: _replyToCommentId, // Pass parentCommentId
      );
      if (!mounted) return;
      _commentController.clear();
      // Reset reply state
      setState(() {
        _replyToCommentId = null;
        _replyToUsername = null;
      });
      // Refetch comments to show the new one
      _fetchComments();
    } catch (e) {
      print('Error submitting comment: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yorum gönderilemedi: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yorumlar'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('Henüz yorum yok.'))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final String commenterUsername = comment.username;
                          final String? commenterAvatarUrl = comment.profilePictureUrl;

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: colorScheme.secondaryContainer,
                              child: ClipOval(
                                child: FadeInImage.assetNetwork(
                                  placeholder: defaultAvatar,
                                  image: _getImageUrl(commenterAvatarUrl),
                                  width: 40, height: 40, fit: BoxFit.cover,
                                  imageErrorBuilder: (c, e, s) {
                                    print('Error loading commenter avatar for $commenterUsername ($commenterAvatarUrl): $e');
                                    return Image.asset(defaultAvatar, width: 40, height: 40, fit: BoxFit.cover);
                                  },
                                  placeholderErrorBuilder: (c,e,s) => Image.asset(defaultAvatar, width: 40, height: 40, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            title: Text(commenterUsername, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            subtitle: Column( // Use Column to stack comment text and action row
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment.commentText, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 4.0), // Space between text and actions
                                Row(
                                  children: [
                                    // Like Button
                                    GestureDetector(
                                      onTap: () async { // Make onTap async
                                        final userState = Provider.of<UserState>(context, listen: false);
                                        final currentUserId = userState.currentUser?['user_id'];

                                        if (currentUserId == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beğenmek için giriş yapmalısınız.')));
                                          return;
                                        }

                                        // Optimistic UI update
                                        setState(() {
                                          if (comment.isLiked) {
                                            comment.likeCount--;
                                          } else {
                                            comment.likeCount++;
                                          }
                                          comment.isLiked = !comment.isLiked;
                                        });

                                        try {
                                          if (comment.isLiked) {
                                            await _apiService.likeComment(comment.id, currentUserId);
                                          } else {
                                            await _apiService.unlikeComment(comment.id, currentUserId);
                                          }
                                        } catch (e) {
                                          print('Error toggling comment like: $e');
                                          // Revert optimistic update on error
                                          setState(() {
                                            if (comment.isLiked) {
                                              comment.likeCount--;
                                            } else {
                                              comment.likeCount++;
                                            }
                                            comment.isLiked = !comment.isLiked;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Beğenme işlemi başarısız: ${e.toString()}')));
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            comment.isLiked ? Icons.favorite : Icons.favorite_border, // Use favorite icon
                                            size: 18.0,
                                            color: comment.isLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            comment.likeCount.toString(),
                                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16.0), // Space between like and reply
                                    // Reply Button
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _replyToCommentId = comment.id;
                                          _replyToUsername = commenterUsername;
                                          _commentController.text = '@$commenterUsername '; // Pre-fill input
                                        });
                                        // Optional: Request focus on the text field
                                        // FocusScope.of(context).requestFocus(_commentFocusNode);
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.reply, // Use reply icon
                                            size: 18.0,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            'Yanıtla',
                                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Optional: Display timestamp
                            // trailing: Text(_formatTimestamp(comment.createdAt)),
                          );
                        },
                      ),
          ),
          // Comment Input Area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _replyToUsername != null ? 'Yanıtlanıyor: $_replyToUsername' : 'Yorum yaz...', // Update hint text
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    ),
                    minLines: 1,
                    maxLines: 5, // Allow multiple lines
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _submitComment,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
