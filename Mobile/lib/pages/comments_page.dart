import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solara/constants/api_constants.dart'; // For defaultAvatar and ApiEndpoints
import 'package:solara/services/api_service.dart';
import 'package:solara/services/user_state.dart';

class CommentsPage extends StatefulWidget {
  final int postId;

  const CommentsPage({super.key, required this.postId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();

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
      final comments = await _apiService.fetchComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
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
      await _apiService.createComment(currentUserId, widget.postId, commentText);
      if (!mounted) return;
      _commentController.clear();
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
                          final String commenterUsername = comment['username'] ?? 'Bilinmeyen';
                          final String? commenterAvatarUrl = comment['profile_picture_url'];

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
                            subtitle: Text(comment['comment_text'] ?? '', style: theme.textTheme.bodyMedium),
                            // Optional: Display timestamp
                            // trailing: Text(_formatTimestamp(comment['created_at'])),
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
                      hintText: 'Yorum yaz...',
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
