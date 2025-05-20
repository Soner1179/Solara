// lib/pages/single_post_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:solara/constants/api_constants.dart'; // For defaultAvatar and ApiEndpoints
import 'package:solara/services/api_service.dart';
import 'package:solara/services/user_state.dart';
import 'package:solara/pages/profile_page.dart';
import 'package:solara/pages/comments_page.dart';
import 'package:solara/widgets/post_card.dart'; // Import the PostCard widget

class SinglePostPage extends StatefulWidget {
  final int postId;

  const SinglePostPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<SinglePostPage> createState() => _SinglePostPageState();
}

class _SinglePostPageState extends State<SinglePostPage> {
  Map<String, dynamic>? _postData; // Make nullable
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPostData(); // Fetch the actual post data
  }

  Future<void> _fetchPostData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ApiService();
      // Use the generic get method with the specific endpoint for a single post
      final dynamic data = await apiService.get('posts/${widget.postId}', requiresAuth: true);

      if (!mounted) return;

      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          // Map backend keys to PostCard expected keys
          _postData = {
            'id': data['post_id']?.toString() ?? 'error_id_${UniqueKey().toString()}', // Ensure ID is string
            'user_id': data['user_id'],
            'username': data['username'] ?? 'unknown_user',
            'avatarUrl': data['profile_picture_url'], // Use backend key, _getImageUrl in PostCard handles URL construction
            'imageUrl': data['image_url'], // Use backend key, _getImageUrl in PostCard handles URL construction
            'caption': data['content_text'] ?? '', // Use backend key
            'likeCount': data['likes_count'] ?? 0, // Map likes_count to likeCount
            'commentCount': data['comments_count'] ?? 0, // Map comments_count to commentCount
            'isLiked': data['is_liked_by_current_user'] ?? false, // Map is_liked_by_current_user to isLiked
            'isBookmarked': data['is_saved_by_current_user'] ?? false, // Map is_saved_by_current_user to isBookmarked
            'timestamp': data['created_at'], // Use backend key, PostCard formats it
            'location': data['location'], // Include location if available
          };
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Gönderi verisi alınamadı veya bulunamadı.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gönderi yüklenirken bir hata oluştu: ${e.toString()}';
        _isLoading = false;
      });
      print('SinglePostPage fetch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_postData?['username'] ?? 'Gönderi'), // Show author's username or 'Gönderi'
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Hata: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
              : _postData == null
                  ? const Center(child: Text('Gönderi bulunamadı.'))
                  : SingleChildScrollView(
                      child: Consumer<UserState>( // Use Consumer to access UserState
                        builder: (context, userState, child) {
                          final currentUserId = userState.currentUser?['user_id'];
                          if (currentUserId == null) {
                            // Handle case where user is not logged in
                            return const Center(child: Text("Gönderiyi görmek için giriş yapın."));
                          }
                          return PostCard(postData: _postData!, userId: currentUserId); // Pass userId
                        },
                      ),
                    ),
    );
  }
}
