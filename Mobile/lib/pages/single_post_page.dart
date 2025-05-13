// lib/pages/single_post_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:solara/constants/api_constants.dart'; // For defaultAvatar and ApiEndpoints
import 'package:solara/services/api_service.dart';
import 'package:solara/services/user_state.dart';
import 'package:solara/pages/profile_page.dart';
import 'package:solara/pages/comments_page.dart';

class SinglePostPage extends StatefulWidget {
  final int postId;

  const SinglePostPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<SinglePostPage> createState() => _SinglePostPageState();
}

class _SinglePostPageState extends State<SinglePostPage> {
  Map<String, dynamic>? _postData;
  bool _isLoading = true;
  String? _errorMessage;

  // --- Asset Paths (Copied from HomePage for consistency) ---
  static const String _iconPath = 'assets/images/';
  static const String likeIcon = '${_iconPath}like.png';
  static const String likeRedIcon = '${_iconPath}like(red).png';
  static const String commentIcon = '${_iconPath}comment.png';
  static const String bookmarkBlackIcon = '${_iconPath}bookmark(black).png';
  static const String bookmarkTappedIcon = '${_iconPath}bookmark(tapped).png';
  static const String postPlaceholderIcon = '${_iconPath}post_placeholder.png';
  static const String _notFoundImage = 'assets/images/not-found.png';
  // static const String defaultAvatar = 'assets/images/avatar.png'; // Using from api_constants
  // --- End Asset Paths ---


  @override
  void initState() {
    super.initState();
    _fetchPostDetails();
  }

  String _getImageUrl(String? relativeOrAbsoluteUrl) {
    if (relativeOrAbsoluteUrl == null || relativeOrAbsoluteUrl.isEmpty) {
      return defaultAvatar;
    }
    if (relativeOrAbsoluteUrl.startsWith('http')) {
      return relativeOrAbsoluteUrl;
    }
    final serverBase = ApiEndpoints.baseUrl.replaceAll('/api', '');
    return '$serverBase$relativeOrAbsoluteUrl';
  }

  Future<void> _fetchPostDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final userState = Provider.of<UserState>(context, listen: false);
      final currentUserId = userState.currentUser?['user_id'];

      // Assuming an endpoint like 'posts/{postId}?userId={currentUserId}'
      // The backend needs to provide post details including author info, like/comment counts,
      // and is_liked / is_bookmarked status for the currentUserId.
      final data = await apiService.get('posts/${widget.postId}${currentUserId != null ? '?userId=$currentUserId' : ''}');
      
      if (!mounted) return;
      setState(() {
        _postData = Map<String, dynamic>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      print('Error fetching post details: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gönderi yüklenemedi: ${e.toString()}';
      });
    }
  }

  String _formatTimestamp(String? apiTimestamp) {
    if (apiTimestamp == null) return 'Just now';
    try {
      DateTime postTime = DateTime.parse(apiTimestamp).toLocal();
      Duration diff = DateTime.now().difference(postTime);
      if (diff.inDays > 7) return '${postTime.day}.${postTime.month}.${postTime.year}';
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      print("Timestamp formatting error: $e");
      return apiTimestamp;
    }
  }

  Future<void> _toggleLike() async {
    if (_postData == null || !mounted) return;

    final int postId = widget.postId; // Already an int
    final bool wasLiked = _postData!['is_liked_by_current_user'] ?? false;
    final int oldLikeCount = _postData!['likes_count'] ?? 0;

    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beğenmek için giriş yapmalısınız.')));
      return;
    }

    setState(() {
      _postData!['is_liked_by_current_user'] = !wasLiked;
      _postData!['likes_count'] = wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (_postData!['is_liked_by_current_user']) {
        await apiService.likePost(postId, currentUserId);
      } else {
        await apiService.unlikePost(postId, currentUserId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postData!['is_liked_by_current_user'] = wasLiked;
        _postData!['likes_count'] = oldLikeCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Beğenme işlemi başarısız: ${e.toString()}')));
    }
  }

  Future<void> _toggleBookmark() async {
    if (_postData == null || !mounted) return;

    final int postId = widget.postId;
    final bool wasBookmarked = _postData!['is_saved_by_current_user'] ?? false;

    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetmek için giriş yapmalısınız.')));
      return;
    }

    setState(() {
      _postData!['is_saved_by_current_user'] = !wasBookmarked;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (_postData!['is_saved_by_current_user']) {
        await apiService.bookmarkPost(postId, currentUserId);
      } else {
        await apiService.unbookmarkPost(postId, currentUserId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postData!['is_saved_by_current_user'] = wasBookmarked;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kaydetme işlemi başarısız: ${e.toString()}')));
    }
  }

  void _navigateToUserProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(username: username)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Gönderi Yükleniyor...')), body: const Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(appBar: AppBar(title: const Text('Hata')), body: Center(child: Text(_errorMessage!)));
    }

    if (_postData == null) {
      return Scaffold(appBar: AppBar(title: const Text('Gönderi Bulunamadı')), body: const Center(child: Text('Bu gönderi artık mevcut değil.')));
    }

    // Extract post data
    final String postUsername = _postData!['username'] ?? 'bilinmeyen';
    final String? postLocation = _postData!['location'];
    final String postAuthorAvatarUrl = _postData!['profile_picture_url'] ?? defaultAvatar;
    final String? postImageUrl = _postData!['image_url'];
    final String postCaption = _postData!['content_text'] ?? '';
    final int likeCount = _postData!['likes_count'] ?? 0;
    final int commentCount = _postData!['comments_count'] ?? 0;
    final bool isLiked = _postData!['is_liked_by_current_user'] ?? false;
    final bool isBookmarked = _postData!['is_saved_by_current_user'] ?? false;
    final String timestamp = _formatTimestamp(_postData!['created_at']);

    final Color textColor = colorScheme.onSurface;
    final Color secondaryTextColor = colorScheme.onSurface.withOpacity(0.7);
    final Color iconColor = theme.iconTheme.color ?? colorScheme.onSurface;
    final Color likeColor = isLiked ? Colors.redAccent : iconColor;
    final Color bookmarkColor = isBookmarked ? colorScheme.primary : iconColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(postUsername), // Show author's username in AppBar
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: iconColor.withOpacity(0.7)),
            tooltip: 'Daha Fazla',
            onPressed: () { /* TODO: Options Menu */ },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Post Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _navigateToUserProfile(postUsername),
                    child: CircleAvatar(
                      radius: 20, // Slightly larger for single post view
                      backgroundColor: colorScheme.secondaryContainer,
                      child: ClipOval(
                        child: FadeInImage.assetNetwork(
                          placeholder: defaultAvatar,
                          image: _getImageUrl(postAuthorAvatarUrl),
                          width: 40, height: 40, fit: BoxFit.cover,
                          imageErrorBuilder: (c, e, s) => Image.asset(defaultAvatar, width: 40, height: 40, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _navigateToUserProfile(postUsername),
                          child: Text(
                            postUsername,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: textColor),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (postLocation != null && postLocation.isNotEmpty)
                          Text(
                            postLocation,
                            style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 2. Post Image
            if (postImageUrl != null && postImageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 1.0, // Or fetch aspect ratio from backend if available
                child: Container(
                  color: theme.dividerColor,
                  child: FadeInImage.assetNetwork(
                    placeholder: postPlaceholderIcon,
                    image: _getImageUrl(postImageUrl), // Use helper for post image too
                    fit: BoxFit.cover,
                    imageErrorBuilder: (c, e, s) => Center(child: Image.asset(_notFoundImage, fit: BoxFit.contain, width: 150, height: 150, color: theme.hintColor)),
                  ),
                ),
              ),
            // 3. Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
              child: Row(
                children: [
                  IconButton(icon: Image.asset(isLiked ? likeRedIcon : likeIcon, width: 28, height: 28, color: likeColor), tooltip: 'Beğen', onPressed: _toggleLike),
                  IconButton(icon: Image.asset(commentIcon, width: 28, height: 28, color: iconColor), tooltip: 'Yorum Yap', onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CommentsPage(postId: widget.postId)));
                  }),
                  const Spacer(),
                  IconButton(icon: Image.asset(isBookmarked ? bookmarkTappedIcon : bookmarkBlackIcon, width: 28, height: 28, color: bookmarkColor), tooltip: 'Kaydet', onPressed: _toggleBookmark),
                ],
              ),
            ),
            // 4. Post Details
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0, top: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (likeCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text('$likeCount beğenme', style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold)),
                    ),
                  if (postCaption.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyLarge?.copyWith(color: textColor, height: 1.4), // Slightly larger text for single post
                          children: [
                            TextSpan(text: '$postUsername ', style: const TextStyle(fontWeight: FontWeight.bold), recognizer: TapGestureRecognizer()..onTap = () => _navigateToUserProfile(postUsername)),
                            TextSpan(text: postCaption),
                          ],
                        ),
                      ),
                    ),
                  if (commentCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommentsPage(postId: widget.postId))),
                        child: Text(commentCount == 1 ? '1 yorumu gör' : '$commentCount yorumun tümünü gör', style: theme.textTheme.bodyMedium?.copyWith(color: secondaryTextColor)),
                      ),
                    ),
                  Text(timestamp, style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
