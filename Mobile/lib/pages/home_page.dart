import 'dart:math'; // Random for placeholders if needed
import 'dart:convert'; // json.decode for potential errors

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:solara/services/theme_service.dart';

// Project imports
import 'package:solara/pages/login_page.dart';
import 'package:solara/pages/profile_page.dart';
import 'package:solara/pages/chats_list_page.dart';
import 'package:solara/pages/create_post_page.dart';
import 'package:solara/pages/saved_posts_page.dart';
import 'package:solara/pages/settings_page.dart';
import 'package:solara/pages/discover_page.dart'; // Import the DiscoverPage
import 'package:solara/pages/comments_page.dart'; // Import the CommentsPage
import 'package:solara/pages/contest_main_page.dart'; // Import the ContestMainPage
import 'package:solara/pages/new_chat_search_page.dart'; // Import NewChatSearchPage
import 'package:solara/pages/notifications_page.dart'; // Import the NotificationsPage // Added import
import 'package:solara/constants/api_constants.dart' show ApiEndpoints, defaultAvatar; // DOĞRU IMPORT
import 'package:solara/services/api_service.dart';
import 'package:solara/services/user_state.dart';
import 'package:solara/widgets/post_card.dart' hide defaultAvatar; // Import the PostCard widget

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;
  Map<String, dynamic>? _previousUser; // Track user changes

  // Helper function to construct image URLs
  String _getImageUrl(String? relativeOrAbsoluteUrl) {
    if (relativeOrAbsoluteUrl == null || relativeOrAbsoluteUrl.isEmpty) {
      return defaultAvatar; // Fallback to default if no URL
    }
    if (relativeOrAbsoluteUrl.startsWith('http')) {
      return relativeOrAbsoluteUrl; // Already an absolute URL
    }
    final serverBase = _apiService.baseUrl.replaceAll('/api', '');
    return '$serverBase$relativeOrAbsoluteUrl';
  }

  // --- Asset Paths ---
  static const String _iconPath = 'assets/images/';
  static const String homeIcon = '${_iconPath}home.png';
  static const String homeBlackIcon = '${_iconPath}home(black).png';
  static const String searchIcon = '${_iconPath}search.png';
  static const String searchBlackIcon = '${_iconPath}search(B).png';
  static const String postIcon = '${_iconPath}post.png';
  static const String postBlackIcon = '${_iconPath}post(black).png';
  static const String notificationIcon = '${_iconPath}notification.png';
  static const String notificationBlackIcon = '${_iconPath}notification(black).png';
  static const String sendIcon = '${_iconPath}send.png';
  static const String sendBlackIcon = '${_iconPath}send(black).png';
  static const String sunShapeIcon = '${_iconPath}sun-shape.png';
  static const String sidebarProfileIcon = '${_iconPath}profile(dark).png';
  static const String sidebarCompetitionIcon = '${_iconPath}competition.png';
  static const String sidebarBookmarkIcon = '${_iconPath}bookmark(black).png';
  static const String sidebarSettingsIcon = '${_iconPath}settings(black).png';
  static const String sidebarLogoutIcon = '${_iconPath}logout(black).png';
  // static const String sidebarContestIcon = '${_iconPath}competition.png'; // Duplicate, remove if not distinct
  static const String moonIcon = '${_iconPath}moon.png';
  static const String likeIcon = '${_iconPath}like.png';
  static const String likeRedIcon = '${_iconPath}like(red).png';
  static const String commentIcon = '${_iconPath}comment.png';
  // static const String bookmarkBlackIcon = '${_iconPath}bookmark(black).png'; // Duplicate of sidebarBookmarkIcon
  static const String bookmarkTappedIcon = '${_iconPath}bookmark(tapped).png';
  static const String postPlaceholderIcon = '${_iconPath}post_placeholder.png';
  static const String _notFoundImage = 'assets/images/not-found.png';
  // --- End Asset Paths ---

  Widget _buildImageWidgetForSidebar(String? imageUrlFromState) {
    final String finalImageUrlToShow;
    bool isNetworkImage = false;

    if (imageUrlFromState != null && imageUrlFromState.isNotEmpty) {
      if (imageUrlFromState.startsWith('http')) {
        finalImageUrlToShow = imageUrlFromState;
        isNetworkImage = true;
      } else if (imageUrlFromState.startsWith('assets/')) {
        finalImageUrlToShow = imageUrlFromState;
        isNetworkImage = false;
      } else if (imageUrlFromState.startsWith('/uploads/')) {
        final serverBase = _apiService.baseUrl.replaceAll('/api', '');
        finalImageUrlToShow = '$serverBase$imageUrlFromState';
        isNetworkImage = true;
        print("_buildImageWidgetForSidebar: UserState'den /uploads/ path geldi, tam URL'ye çevrildi: $finalImageUrlToShow");
      } else {
        print("_buildImageWidgetForSidebar: UserState'den gelen imageUrl ('$imageUrlFromState') beklenmedik formatta, defaultAvatar kullanılıyor.");
        finalImageUrlToShow = defaultAvatar;
        isNetworkImage = false;
      }
    } else {
      print("_buildImageWidgetForSidebar: UserState imageUrl null veya boş, defaultAvatar kullanılıyor.");
      finalImageUrlToShow = defaultAvatar;
      isNetworkImage = false;
    }

    if (isNetworkImage) {
      return FadeInImage.assetNetwork(
        placeholder: defaultAvatar,
        image: finalImageUrlToShow,
        fit: BoxFit.cover,
        width: 60,
        height: 60,
        imageErrorBuilder: (context, error, stackTrace) {
          print('Error loading sidebar avatar (FadeInImage.assetNetwork) for $finalImageUrlToShow: $error');
          return Image.asset(defaultAvatar, fit: BoxFit.cover, width: 60, height: 60);
        },
        placeholderErrorBuilder: (context, error, stackTrace) {
          print('Error loading sidebar placeholder asset: $error');
          return const Icon(Icons.person, size: 30);
        },
      );
    } else {
      return Image.asset(
        finalImageUrlToShow,
        fit: BoxFit.cover,
        width: 60,
        height: 60,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading sidebar avatar (Image.asset) for $finalImageUrlToShow: $error');
          return const Icon(Icons.person, size: 30);
        },
      );
    }
  }

  List<Map<String, dynamic>> _posts = [];
  bool _isLoadingPosts = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    print("HomePage initState");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print("HomePage didChangeDependencies triggered");
    final userState = Provider.of<UserState>(context);
    final currentUser = userState.currentUser;
    final currentUserId = currentUser?['user_id'];
    final previousUserId = _previousUser?['user_id'];

    print("Current User ID: $currentUserId, Previous User ID: $previousUserId");

    if (currentUserId != previousUserId) {
      print("User state changed. New User ID: $currentUserId");
      _previousUser = currentUser;
      if (currentUserId != null) {
        _fetchPosts(currentUserId);
      } else {
        print("User logged out, clearing posts.");
        if (mounted) {
          setState(() {
            _posts = [];
            _isLoadingPosts = false;
          });
        }
      }
    } else if (_posts.isEmpty && !_isLoadingPosts && currentUserId != null && previousUserId == null) {
      print("Initial load detected with logged-in user. Fetching posts.");
      _previousUser = currentUser;
      _fetchPosts(currentUserId);
    }
  }

  Future<void> _fetchPosts(int currentUserId) async {
    if (!mounted) return;
    print("Fetching posts for user $currentUserId...");
    setState(() { _isLoadingPosts = true; });

    try {
      final List<dynamic> data = await _apiService.fetchPosts(currentUserId);
      if (!mounted) return;

      setState(() {
        _posts = List<Map<String, dynamic>>.from(data.map((post) {
          return {
            'id': post['post_id']?.toString() ?? Random().nextInt(99999).toString(),
            'user_id': post['user_id'],
            'username': post['username'] ?? 'unknown_user',
            'avatarUrl': (() {
              final String? backendAvatarPath = post['profile_picture_url'] as String?;
              if (backendAvatarPath != null && backendAvatarPath.isNotEmpty) {
                if (backendAvatarPath.startsWith('/uploads/')) {
                  return '${_apiService.baseUrl.replaceAll('/api', '')}$backendAvatarPath';
                } else if (backendAvatarPath.startsWith('http://') || backendAvatarPath.startsWith('https://')) {
                  return backendAvatarPath;
                }
              }
              return defaultAvatar;
            })(),
            'imageUrl': post['image_url'],
            'caption': post['content_text'] ?? '',
            'likeCount': post['likes_count'] ?? 0,
            'commentCount': post['comments_count'] ?? 0,
            'isLiked': post['is_liked_by_current_user'] ?? false,
            'isBookmarked': post['is_saved_by_current_user'] ?? false,
            'timestamp': _formatTimestamp(post['created_at']),
          };
        }));
        _isLoadingPosts = false;
        print("Posts fetched successfully: ${_posts.length} posts");
      });
    } catch (e) {
      print('Error fetching posts in _fetchPosts: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gönderiler yüklenemedi: ${e.toString()}')));
      setState(() { _isLoadingPosts = false; });
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

  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _posts.length || !mounted) return;

    final post = _posts[index];
    final String postIdStr = post['id'];
    final int? postId = int.tryParse(postIdStr);
    final bool wasLiked = post['isLiked'];
    final int oldLikeCount = post['likeCount'];

    if (postId == null) {
      print("Error: Invalid post ID for liking: $postIdStr");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem başarısız: Geçersiz gönderi IDsi.')));
      return;
    }

    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    if (currentUserId == null) {
      print("Error: User must be logged in to like posts.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beğenmek için giriş yapmalısınız.')));
      return;
    }

    setState(() {
      post['isLiked'] = !wasLiked;
      post['likeCount'] = wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
    });
    print('Post ID $postId: Like Tapped. New Status: ${post['isLiked']}, New Count: ${post['likeCount']}');

    try {
      // Note: The API call here seems to be for bookmarking, not liking. This might be a bug.
      // Assuming it should be _apiService.likePost or _apiService.unlikePost
      if (post['isLiked']) { // If it's now liked, call like API
        await _apiService.likePost(postId, currentUserId); // Example: This method needs to exist in ApiService
        print('API: Post $postId liked successfully.');
      } else { // If it's now unliked, call unlike API
        await _apiService.unlikePost(postId, currentUserId); // Example: This method needs to exist in ApiService
        print('API: Post $postId unliked successfully.');
      }
    } catch (e) {
      print('API Error toggling like for post $postId: $e');
      if (!mounted) return;
      setState(() {
        post['isLiked'] = wasLiked;
        post['likeCount'] = oldLikeCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beğenme işlemi başarısız: ${e.toString()}')),
      );
    }
  }

  void _navigateToProfile({String? username}) {
    final userState = Provider.of<UserState>(context, listen: false);
    final loggedInUsername = userState.currentUser?['username'];
    final targetUsername = (username == null || username == loggedInUsername) ? loggedInUsername : username;

    if (targetUsername == null || targetUsername.isEmpty) {
      print("Error navigating to profile: Target username is null or empty. Is user logged in?");
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (Route<dynamic> route) => false,);
      }
      return;
    }

    print("Navigating to profile: $targetUsername");
    if (_isSidebarOpen) {
      setState(() { _isSidebarOpen = false; });
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _pushProfilePage(targetUsername);
      });
    } else {
      _pushProfilePage(targetUsername);
    }
  }

  void _pushProfilePage(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(username: username)),
    );
  }

  void _navigateToCreatePost() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi oluşturmak için giriş yapmalısınız.')));
      return;
    }

    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage()));

    if (result is int && mounted) {
      setState(() {
        _selectedIndex = result;
      });
      print("Navigated back from CreatePostPage, setting selected index to $result");
    } else if (result == true && mounted) {
      print("Post created successfully, refreshing feed...");
      _fetchPosts(currentUserId);
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      setState(() { _selectedIndex = index; });
      _navigateToCreatePost();
      return;
    }

    if (index == _selectedIndex) {
      if (index == 0) {
        final userState = Provider.of<UserState>(context, listen: false);
        final currentUserId = userState.currentUser?['user_id'];
        if (currentUserId != null) {
          _fetchPosts(currentUserId);
        }
      }
      print("Tapped on already selected index: $index.");
      return;
    }
    setState(() { _selectedIndex = index; });
  }

  void _logout() {
    if (_isSidebarOpen) {
      setState(() { _isSidebarOpen = false; });
      Future.delayed(const Duration(milliseconds: 260), _performLogout);
    } else {
      _performLogout();
    }
  }

  void _performLogout() async {
    print("Performing logout...");
    if (mounted) {
      await Provider.of<UserState>(context, listen: false).logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Widget _buildNavIcon(String path, {double size = 24}) {
    return Image.asset(
      path, width: size, height: size,
      errorBuilder: (context, error, stackTrace) {
        print('Nav icon load error ($path): $error');
        return Icon(Icons.broken_image_outlined, size: size, color: Colors.grey.shade600);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeService = Provider.of<ThemeService>(context);

    print("HomePage build method running. SelectedIndex: $_selectedIndex");

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: _selectedIndex == 4
            ? const Text('Sohbetler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(sunShapeIcon, width: 24, height: 24, color: theme.brightness == Brightness.dark ? Colors.orangeAccent : null, errorBuilder: (c,e,s) => Icon(Icons.wb_sunny_rounded, size: 24, color: Colors.orangeAccent[200])),
                  const SizedBox(width: 8),
                  const Text('Solara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                ],
              ),
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 28),
          tooltip: 'Menü',
          onPressed: () => setState(() { _isSidebarOpen = !_isSidebarOpen; }),
        ),
        actions: _selectedIndex == 4
            ? [
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined),
                  tooltip: 'Yeni Sohbet Başlat',
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NewChatSearchPage()),
                    );
                    print("New chat search page closed with result: $result");
                  },
                ),
              ]
            : [],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              RefreshIndicator(
                 onRefresh: () async {
                   final userState = Provider.of<UserState>(context, listen: false);
                   final currentUserId = userState.currentUser?['user_id'];
                   if (currentUserId != null) {
                     await _fetchPosts(currentUserId);
                   } else {
                      print("Cannot refresh: User not logged in.");
                   }
                 },
                 color: colorScheme.primary,
                 backgroundColor: theme.cardColor,
                 child: _buildPostList(),
              ),
              const DiscoverPage(),
              Container(), // Placeholder for Create Post (handled by navigation)
              const NotificationsPage(), // Replaced static text with NotificationsPage
              const ChatsListPage(),
            ],
          ),
          if (_isSidebarOpen)
            GestureDetector(
              onTap: () => setState(() { _isSidebarOpen = false; }),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            transform: Matrix4.translationValues( _isSidebarOpen ? 0 : -MediaQuery.of(context).size.width * 0.75, 0, 0,),
            width: MediaQuery.of(context).size.width * 0.75,
            height: double.infinity,
            decoration: BoxDecoration( color: theme.canvasColor, boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.25), blurRadius: 20, spreadRadius: 2,) ],),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<UserState>(
                    builder: (context, userState, child) {
                      final currentUser = userState.currentUser;
                      final username = currentUser?['username'] ?? 'Misafir';
                      final avatarUrl = currentUser?['profile_picture_url']; // Let _buildImageWidgetForSidebar handle default
                       return InkWell(
                        onTap: () => _navigateToProfile(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          child: Row(
                             children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: colorScheme.secondaryContainer,
                                child: ClipOval(
                                  child: _buildImageWidgetForSidebar(avatarUrl),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text( username, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis,),
                                    const SizedBox(height: 4),
                                    Text( "Profili Görüntüle", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, thickness: 0.5, color: theme.dividerColor, indent: 16, endIndent: 16),
                  const SizedBox(height: 10),
                  _buildSidebarMenuItem( icon: sidebarProfileIcon, title: 'Profilim', onTap: () => _navigateToProfile(), ),
                  _buildSidebarMenuItem( icon: sidebarCompetitionIcon, title: 'Yarışma', onTap: () { setState(() { _isSidebarOpen = false; }); Future.delayed(const Duration(milliseconds: 260), () { if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => ContestMainPage())); }); }, ),
                  _buildSidebarMenuItem( icon: sidebarBookmarkIcon, title: 'Kaydedilenler', onTap: () { setState(() { _isSidebarOpen = false; }); Future.delayed(const Duration(milliseconds: 260), () { if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPostsPage())); }); }, ),
                  _buildSidebarMenuItem( icon: sidebarSettingsIcon, title: 'Ayarlar', onTap: () { setState(() { _isSidebarOpen = false; }); Future.delayed(const Duration(milliseconds: 260), () { if (mounted) { Navigator.push( context, MaterialPageRoute(builder: (context) => const SettingsPage()), ); print("Navigating to SettingsPage"); } }); }, ),
                  _buildSidebarMenuItem( icon: themeService.themeMode == ThemeMode.dark ? sunShapeIcon : moonIcon, title: themeService.themeMode == ThemeMode.dark ? 'Gündüz Modu' : 'Gece Modu', onTap: () { themeService.toggleTheme(); }, ),
                  const Expanded(child: SizedBox()),
                  Divider(height: 1, thickness: 0.5, color: theme.dividerColor, indent: 16, endIndent: 16),
                  _buildSidebarMenuItem( icon: sidebarLogoutIcon, title: 'Çıkış Yap', onTap: _logout,),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        items: [
          BottomNavigationBarItem( icon: _buildNavIcon(homeIcon), activeIcon: _buildNavIcon(homeBlackIcon), label: 'Ana Sayfa',),
          BottomNavigationBarItem( icon: _buildNavIcon(searchIcon), activeIcon: _buildNavIcon(searchBlackIcon), label: 'Keşfet',),
          BottomNavigationBarItem( icon: _buildNavIcon(postIcon), activeIcon: _buildNavIcon(postBlackIcon), label: 'Oluştur',),
          BottomNavigationBarItem( icon: _buildNavIcon(notificationIcon), activeIcon: _buildNavIcon(notificationBlackIcon), label: 'Bildirimler',),
          BottomNavigationBarItem( icon: _buildNavIcon(sendIcon), activeIcon: _buildNavIcon(sendBlackIcon), label: 'Mesajlar',),
        ],
      ),
    );
  }

  Widget _buildSidebarMenuItem({ required String icon, required String title, required VoidCallback onTap,}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Color? iconColor = theme.iconTheme.color?.withOpacity(0.8);
    TextStyle? textStyle = theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: colorScheme.primary.withOpacity(0.1),
        highlightColor: colorScheme.primary.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              Image.asset( icon, width: 24, height: 24, color: iconColor, errorBuilder: (c,e,s) => Icon( Icons.error_outline, size: 24, color: iconColor ?? Colors.grey.shade700,),),
              const SizedBox(width: 16),
              Text( title, style: textStyle,),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingPosts && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isLoadingPosts && _posts.isEmpty) {
       final userState = Provider.of<UserState>(context, listen: false);
       final currentUserId = userState.currentUser?['user_id'];
       final message = currentUserId == null
           ? "Gönderileri görmek için giriş yapın."
           : "Takip ettiğiniz kişilerden henüz gönderi yok veya\nakışınızı yenilemek için aşağı çekin.";

      return LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor)),
            )),
          ),
        );
      });
    }

    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];

    if (currentUserId == null) {
      // Handle the case where the user is not logged in, maybe show a message or redirect
      return Center(child: Text("Gönderileri görmek için giriş yapın.", style: TextStyle(color: theme.hintColor)));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 10),
      itemCount: _posts.length + (_isLoadingPosts ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingPosts && index == _posts.length) {
           return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final postData = _posts[index];
        // The post_id is now directly in postData with the key 'post_id'
        // final String postId = postData['id'] ?? 'error_id_$index'; // This line is no longer needed for getting post ID for PostCard
        final String postUsername = postData['username'] ?? 'bilinmeyen';
        final String? postLocation = postData['location'];
        final String postAvatarUrl = postData['avatarUrl'] ?? defaultAvatar;
        final String? postImageUrl = postData['imageUrl'];
        final String postCaption = postData['caption'] ?? ''; // Corrected key
        final int likeCount = postData['likeCount'] ?? 0;
        final int commentCount = postData['commentCount'] ?? 0;
        final bool isLiked = postData['isLiked'] ?? false;
        final bool isBookmarked = postData['isBookmarked'] ?? false;
        return PostCard(postData: postData, userId: currentUserId);
      },
    );
  }

  Future<void> _toggleBookmark(int index) async {
    if (index < 0 || index >= _posts.length || !mounted) return;

    final post = _posts[index];
    final int? postId = post['post_id'] as int?; // Access post_id directly as int?
    final bool wasBookmarked = post['isBookmarked'];

    if (postId == null) {
      print("Error: post_id is null for bookmarking."); // Updated error message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem başarısız: Geçersiz gönderi IDsi.')));
      return;
    }

    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    if (currentUserId == null) {
      print("Error: User must be logged in to bookmark posts.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetmek için giriş yapmalısınız.')));
      return;
    }

    setState(() {
      post['isBookmarked'] = !wasBookmarked;
    });
    print('Post ID $postId: Bookmark Tapped. New Status: ${post['isBookmarked']}');

    try {
      if (post['isBookmarked']) {
        await _apiService.bookmarkPost(postId, currentUserId);
        print('API: Post $postId bookmarked successfully.');
      } else {
        await _apiService.unbookmarkPost(postId, currentUserId);
        print('API: Post $postId unbookmarked successfully.');
      }
    } catch (e) {
      print('API Error toggling bookmark for post $postId: $e');
      if (!mounted) return;
      setState(() {
        post['isBookmarked'] = wasBookmarked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydetme işlemi başarısız: ${e.toString()}')),
      );
    }
  }
}
