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
// import 'package:solara/pages/comments_page.dart'; // Import if you create a comments page/modal
import 'package:solara/constants/api_constants.dart'; // Import baseUrl
import 'package:solara/services/api_service.dart';
import 'package:solara/services/user_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;
  Map<String, dynamic>? _previousUser; // Track user changes

  // --- Asset Paths ---
  static const String _iconPath = 'assets/images/';
  // ... (keep all your icon path constants here) ...
  static const String homeIcon = '${_iconPath}home.png';
  static const String homeBlackIcon = '${_iconPath}home(black).png';
  static const String searchIcon = '${_iconPath}search.png';
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
  static const String moonIcon = '${_iconPath}moon.png';
  static const String likeIcon = '${_iconPath}like.png';
  static const String likeRedIcon = '${_iconPath}like(red).png';
  static const String commentIcon = '${_iconPath}comment.png';
  static const String bookmarkBlackIcon = '${_iconPath}bookmark(black).png';
  static const String bookmarkTappedIcon = '${_iconPath}bookmark(tapped).png';
  static const String postPlaceholderIcon = '${_iconPath}post_placeholder.png';
  static const String _notFoundImage = 'assets/images/not-found.png';
  static const String defaultAvatar = 'assets/images/avatar.png'; // Default avatar
  // --- End Asset Paths ---

  List<Map<String, dynamic>> _posts = [];
  bool _isLoadingPosts = false; // Start as false, set true before fetching
  final ApiService _apiService = ApiService(); // Instantiate ApiService once

  @override
  void initState() {
    super.initState();
    // Initial fetch is handled in didChangeDependencies
    print("HomePage initState");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print("HomePage didChangeDependencies triggered");
    final userState = Provider.of<UserState>(context); // Don't listen=false here if UI depends on it
    final currentUser = userState.currentUser;
    final currentUserId = currentUser?['user_id'];
    final previousUserId = _previousUser?['user_id'];

    print("Current User ID: $currentUserId, Previous User ID: $previousUserId");

    // Check if user has changed (login/logout)
    if (currentUserId != previousUserId) {
       print("User state changed. New User ID: $currentUserId");
      _previousUser = currentUser; // Update tracked user
      if (currentUserId != null) {
        // User logged in or changed, fetch their feed
        _fetchPosts(currentUserId);
      } else {
        // User logged out, clear posts
        print("User logged out, clearing posts.");
        if (mounted) {
          setState(() {
            _posts = [];
            _isLoadingPosts = false; // Stop loading indicator if logout happens during load
          });
        }
      }
    }
    // Handle initial load if user is already logged in but posts haven't been fetched
    else if (_posts.isEmpty && !_isLoadingPosts && currentUserId != null && previousUserId == null) {
        print("Initial load detected with logged-in user. Fetching posts.");
         _previousUser = currentUser; // Make sure previous user is set
         _fetchPosts(currentUserId);
    }
  }

  Future<void> _fetchPosts(int currentUserId) async {
    if (!mounted) return;
    print("Fetching posts for user $currentUserId...");
    setState(() { _isLoadingPosts = true; });

    try {
      // Use the ApiService instance with the current user's ID
      final List<dynamic> data = await _apiService.fetchPosts(currentUserId);

      if (!mounted) return; // Check again after async operation

       // TODO: Process data to include 'is_liked' and 'is_saved' based on API response
       // Backend needs to return this info relative to currentUserId

      setState(() {
        _posts = List<Map<String, dynamic>>.from(data.map((post) {
          // Basic mapping, assumes backend returns counts but not user-specific like/save status yet
          return {
           'id': post['post_id']?.toString() ?? Random().nextInt(99999).toString(), // Ensure ID is string
           'user_id': post['user_id'],
           'username': post['username'] ?? 'unknown_user',
           'avatarUrl': post['profile_picture_url'] ?? defaultAvatar, // Use default avatar
           'imageUrl': post['image_url'], // Can be null, handle in UI
           'caption': post['content_text'] ?? '',
           'likeCount': post['likes_count'] ?? 0,
           'commentCount': post['comments_count'] ?? 0,
           // --- IMPORTANT: These need to come from the backend ---
           'isLiked': post['is_liked_by_current_user'] ?? false, // Replace with actual field from API
           'isBookmarked': post['is_saved_by_current_user'] ?? false, // Replace with actual field from API
           // --- End Important ---
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
      return apiTimestamp; // Return raw on error
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

    // Get current user ID
    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    if (currentUserId == null) {
      print("Error: User must be logged in to like posts.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beğenmek için giriş yapmalısınız.')));
      // Optionally navigate to login
      return;
    }

    // --- Optimistic UI Update ---
    setState(() {
      post['isLiked'] = !wasLiked;
      post['likeCount'] = wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
    });
    print('Post ID $postId: Like Tapped. New Status: ${post['isLiked']}, New Count: ${post['likeCount']}');

    // --- API Call ---
    try {
      if (post['isLiked']) {
        // If UI shows liked, call like API
        await _apiService.likePost(postId, currentUserId);
        print('API: Post $postId liked successfully.');
      } else {
        // If UI shows not liked, call unlike API
        await _apiService.unlikePost(postId, currentUserId);
        print('API: Post $postId unliked successfully.');
      }
    } catch (e) {
      print('API Error toggling like for post $postId: $e');
      if (!mounted) return;
      // --- Revert UI on Error ---
      setState(() {
        post['isLiked'] = wasLiked;
        post['likeCount'] = oldLikeCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beğenme işlemi başarısız: ${e.toString()}')),
      );
    }
 }

  Future<void> _toggleBookmark(int index) async {
    if (index < 0 || index >= _posts.length || !mounted) return;

    final post = _posts[index];
    final String postIdStr = post['id'];
    final int? postId = int.tryParse(postIdStr);
    final bool wasBookmarked = post['isBookmarked'];

     if (postId == null) {
      print("Error: Invalid post ID for bookmarking: $postIdStr");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem başarısız: Geçersiz gönderi IDsi.')));
      return;
    }

    // Get current user ID
    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    if (currentUserId == null) {
      print("Error: User must be logged in to bookmark posts.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetmek için giriş yapmalısınız.')));
      return;
    }

    // --- Optimistic UI Update ---
    setState(() {
      post['isBookmarked'] = !wasBookmarked;
    });
    print('Post ID $postId: Bookmark Tapped. New Status: ${post['isBookmarked']}');

    // --- API Call ---
    try {
       if (post['isBookmarked']) {
        // If UI shows bookmarked, call bookmark API
        await _apiService.bookmarkPost(postId, currentUserId);
        print("API: Post $postId bookmarked successfully.");
      } else {
         // If UI shows not bookmarked, call unbookmark API
        await _apiService.unbookmarkPost(postId, currentUserId);
        print("API: Post $postId unbookmarked successfully.");
      }
    } catch (e) {
      print('API Error toggling bookmark for post $postId: $e');
       if (!mounted) return;
       // --- Revert UI on Error ---
       setState(() {
        post['isBookmarked'] = wasBookmarked;
       });
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydetme işlemi başarısız oldu: ${e.toString()}')),
       );
    }
  }


  void _navigateToProfile({String? username}) {
     final userState = Provider.of<UserState>(context, listen: false);
     final loggedInUsername = userState.currentUser?['username'];
     final targetUsername = (username == null || username == loggedInUsername) ? loggedInUsername : username;

    if (targetUsername == null || targetUsername.isEmpty) {
      print("Error navigating to profile: Target username is null or empty. Is user logged in?");
       // Maybe navigate to login?
       if (mounted) {
         Navigator.pushAndRemoveUntil( context, MaterialPageRoute(builder: (context) => const LoginPage()), (Route<dynamic> route) => false,);
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

  // Navigate to Create Post Page, refreshing feed on success
  void _navigateToCreatePost() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi oluşturmak için giriş yapmalısınız.')));
      // Optionally navigate to login
      return;
    }

    // Navigate and wait for a result (e.g., true if post was created)
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage()));

    // If CreatePostPage indicates success, refresh the feed
    if (result == true && mounted) {
       print("Post created successfully, refreshing feed...");
      _fetchPosts(currentUserId);
    }
  }


  // Define the list of pages for the bottom navigation bar
  final List<Widget> _pages = [
    // Index 0: Home Feed
    // The post list is built directly in the body, so we'll handle this differently
    // For now, we'll use a placeholder or the post list builder directly in the Stack
    // We'll refine this to use a dedicated HomeFeedPage widget later if needed.
    Container(), // Placeholder for Home Feed (handled by _buildPostList)
    // Index 1: Discover Page
    const DiscoverPage(),
    // Index 2: Create Post (Handled by navigation, not a page in the stack)
    Container(), // Placeholder
    // Index 3: Notifications (Coming Soon)
    const Center(child: Text('Bildirimler bölümü yakında.')),
    // Index 4: Messages (Handled by navigation, not a page in the stack)
    Container(), // Placeholder
  ];


  void _onItemTapped(int index) {
    // Handle Create and Messages navigation (these are separate pages, not part of the indexed stack)
    if (index == 2) { // Create Post
      _navigateToCreatePost();
      return; // Don't change _selectedIndex
    }
    if (index == 4) { // Messages
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatsListPage()));
       return; // Don't change _selectedIndex
    }

    // Handle other tabs (Home, Discover, Notifications)
    if (index == _selectedIndex) {
      // If tapping on the currently selected tab
      if (index == 0) {
         // If on Home tab, refresh the feed (assuming _buildPostList is the feed)
         final userState = Provider.of<UserState>(context, listen: false);
         final currentUserId = userState.currentUser?['user_id'];
         if (currentUserId != null) {
           _fetchPosts(currentUserId);
         }
      }
      // For other tabs, maybe scroll to top if they were scrollable? (Not implemented yet)
      print("Tapped on already selected index: $index.");
      return;
    }

    // Update state for other tabs (Home, Discover, Notifications)
    setState(() { _selectedIndex = index; });

    // No "Coming Soon" snackbars needed anymore as pages are implemented or have placeholders
  }

  void _logout() {
    // Close sidebar first if open
    if (_isSidebarOpen) {
      setState(() { _isSidebarOpen = false; });
      // Wait for animation before navigating
      Future.delayed(const Duration(milliseconds: 260), _performLogout);
    } else {
      _performLogout();
    }
  }

  void _performLogout() async {
    print("Performing logout...");
    if (mounted) {
      // Clear user state using Provider
      await Provider.of<UserState>(context, listen: false).logout();

      // Navigate to LoginPage and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // Helper for building nav icons (no changes needed)
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
    final themeService = Provider.of<ThemeService>(context); // For theme toggle

    print("HomePage build method running. SelectedIndex: $_selectedIndex");

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row( /* ... (AppBar title remains the same) ... */
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset( sunShapeIcon, width: 24, height: 24, color: theme.brightness == Brightness.dark ? Colors.orangeAccent : null, errorBuilder: (c,e,s) => Icon(Icons.wb_sunny_rounded, size: 24, color: Colors.orangeAccent[200]), ),
            const SizedBox(width: 8),
            const Text('Solara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        leading: IconButton( /* ... (AppBar leading remains the same) ... */
          icon: const Icon(Icons.menu, size: 28),
          tooltip: 'Menü',
          onPressed: () => setState(() { _isSidebarOpen = !_isSidebarOpen; }),
        ),
        // Optional: Add refresh button to AppBar
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.refresh),
        //     tooltip: 'Yenile',
        //     onPressed: () {
        //        final userState = Provider.of<UserState>(context, listen: false);
        //        final currentUserId = userState.currentUser?['user_id'];
        //        if (currentUserId != null) {
        //          _fetchPosts(currentUserId);
        //        }
        //     },
        //   ),
        // ],
      ),
      body: Stack( // Use Stack to layer sidebar over content
        children: [
          // Main Content Area (Displays the selected page)
          IndexedStack( // Use IndexedStack to keep pages alive
            index: _selectedIndex,
            children: [
              // Index 0: Home Feed (Use the existing _buildPostList wrapped in a RefreshIndicator)
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
                 child: _buildPostList(), // Your feed widget
              ),
              // Index 1: Discover Page
              const DiscoverPage(),
              // Index 2: Create Post (Placeholder, handled by navigation)
              Container(),
              // Index 3: Notifications (Placeholder/Coming Soon)
              const Center(child: Text('Bildirimler bölümü yakında.')),
              // Index 4: Messages (Placeholder, handled by navigation)
              Container(),
            ],
          ),


          // Sidebar Overlay and Panel
          if (_isSidebarOpen)
            GestureDetector( // ... (Sidebar overlay remains the same) ...
              onTap: () => setState(() { _isSidebarOpen = false; }),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          AnimatedContainer( // ... (Sidebar panel animation remains the same) ...
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            transform: Matrix4.translationValues( _isSidebarOpen ? 0 : -MediaQuery.of(context).size.width * 0.75, 0, 0,),
            width: MediaQuery.of(context).size.width * 0.75,
            height: double.infinity,
            decoration: BoxDecoration( color: theme.canvasColor, boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.25), blurRadius: 20, spreadRadius: 2,) ],),
            child: SafeArea(
              child: Column( // --- Sidebar Content ---
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section (Uses Consumer for UserState)
                  Consumer<UserState>( // ... (Sidebar profile section remains the same) ...
                    builder: (context, userState, child) {
                      final currentUser = userState.currentUser;
                      final username = currentUser?['username'] ?? 'Misafir';
                      final avatarUrl = currentUser?['profile_picture_url'] ?? defaultAvatar;
                       return InkWell(
                        onTap: () => _navigateToProfile(), // Navigates to own profile
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          child: Row( /* ... (Avatar and Name) ... */
                             children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: colorScheme.secondaryContainer,
                                child: ClipOval(
                                  child: Image.network( // Use network image if URL
                                    '$baseUrl/uploads/pp.png', // Use static path
                                    fit: BoxFit.cover, width: 60, height: 60,
                                    errorBuilder: (context, error, stackTrace) => Image.asset( defaultAvatar, fit: BoxFit.cover, width: 60, height: 60,),
                                     loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column( /* ... (Username and "View Profile") ... */
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

                  // Menu Items (No changes needed here unless adding new items)
                  _buildSidebarMenuItem( icon: sidebarProfileIcon, title: 'Profilim', onTap: () => _navigateToProfile(), ),
                  _buildSidebarMenuItem( icon: sidebarCompetitionIcon, title: 'Yarışma', onTap: () { /* ... (Coming Soon) ... */ setState(() { _isSidebarOpen = false; }); ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Yarışma bölümü yakında.')), ); }, ),
                  _buildSidebarMenuItem( icon: sidebarBookmarkIcon, title: 'Kaydedilenler', onTap: () { setState(() { _isSidebarOpen = false; }); Future.delayed(const Duration(milliseconds: 260), () { if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPostsPage())); }); }, ),
                  _buildSidebarMenuItem( icon: sidebarSettingsIcon, title: 'Ayarlar', onTap: () { setState(() { _isSidebarOpen = false; }); Future.delayed(const Duration(milliseconds: 260), () { if (mounted) { Navigator.push( context, MaterialPageRoute(builder: (context) => const SettingsPage()), ); print("Navigating to SettingsPage"); } }); }, ),
                  _buildSidebarMenuItem( icon: themeService.themeMode == ThemeMode.dark ? sunShapeIcon : moonIcon, title: themeService.themeMode == ThemeMode.dark ? 'Gündüz Modu' : 'Gece Modu', onTap: () { themeService.toggleTheme(); }, ),

                  const Expanded(child: SizedBox()), // Spacer
                  Divider(height: 1, thickness: 0.5, color: theme.dividerColor, indent: 16, endIndent: 16),
                  _buildSidebarMenuItem( icon: sidebarLogoutIcon, title: 'Çıkış Yap', onTap: _logout,), // Calls updated logout
                  const SizedBox(height: 16),
                ], // --- End Sidebar Content ---
              ),
            ),
          ), // --- End Sidebar Panel ---
        ],
      ),
      bottomNavigationBar: BottomNavigationBar( // ... (Bottom Nav Bar remains the same) ...
        currentIndex: _selectedIndex,
        onTap: _onItemTapped, // Uses updated onTap handler
        type: BottomNavigationBarType.fixed,
        // Ensure theme provides styling or set explicitly
         // backgroundColor: theme.bottomAppBarColor,
         // selectedItemColor: colorScheme.primary,
         // unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        items: [
          BottomNavigationBarItem( icon: _buildNavIcon(homeIcon), activeIcon: _buildNavIcon(homeBlackIcon), label: 'Ana Sayfa',),
          BottomNavigationBarItem( icon: _buildNavIcon(searchIcon), activeIcon: _buildNavIcon(searchIcon), label: 'Keşfet',),
          BottomNavigationBarItem( icon: _buildNavIcon(postIcon), activeIcon: _buildNavIcon(postBlackIcon), label: 'Oluştur',),
          BottomNavigationBarItem( icon: _buildNavIcon(notificationIcon), activeIcon: _buildNavIcon(notificationBlackIcon), label: 'Bildirimler',),
          BottomNavigationBarItem( icon: _buildNavIcon(sendIcon), activeIcon: _buildNavIcon(sendBlackIcon), label: 'Mesajlar',),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  // Sidebar Menu Item Builder (No changes needed)
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

  // Post List Builder
  Widget _buildPostList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Loading State
    if (_isLoadingPosts && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Empty State (After loading)
    if (!_isLoadingPosts && _posts.isEmpty) {
       // Get current user ID to check if logged in
       final userState = Provider.of<UserState>(context, listen: false);
       final currentUserId = userState.currentUser?['user_id'];
       final message = currentUserId == null
           ? "Gönderileri görmek için giriş yapın."
           : "Takip ettiğiniz kişilerden henüz gönderi yok veya\nakışınızı yenilemek için aşağı çekin.";

      return LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Allow refresh even when empty
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

    // Post List
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 10), // Padding below list
      itemCount: _posts.length + (_isLoadingPosts ? 1 : 0), // Add space for loader if loading more
      itemBuilder: (context, index) {
        // Show loading indicator at the end if still loading (for pagination later)
        if (_isLoadingPosts && index == _posts.length) {
           return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final postData = _posts[index];
        // Extract post data (use null checks and defaults)
        final String postId = postData['id'] ?? 'error_id_$index';
        final String postUsername = postData['username'] ?? 'bilinmeyen';
        final String? postLocation = postData['location']; // Optional field
        final String postAvatarUrl = postData['avatarUrl'] ?? defaultAvatar;
        final String? postImageUrl = postData['imageUrl']; // Can be null
        final String postCaption = postData['caption'] ?? '';
        final int likeCount = postData['likeCount'] ?? 0;
        final int commentCount = postData['commentCount'] ?? 0;
        final bool isLiked = postData['isLiked'] ?? false; // Default to false if not provided
        final bool isBookmarked = postData['isBookmarked'] ?? false; // Default to false
        final String timestamp = postData['timestamp'] ?? '';

        // Get theme colors for card elements
        final Color textColor = colorScheme.onSurface;
        final Color secondaryTextColor = colorScheme.onSurface.withOpacity(0.7);
        final Color iconColor = theme.iconTheme.color ?? colorScheme.onSurface;
        final Color likeColor = isLiked ? Colors.redAccent : iconColor;
        final Color bookmarkColor = isBookmarked ? colorScheme.primary : iconColor; // Use primary color when bookmarked

        // Build Post Card (Consider making this a separate StatefulWidget for better state management)
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Post Header
              Padding( // ... (Post Header structure remains the same) ...
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    GestureDetector( onTap: () => _navigateToProfile(username: postUsername), child: CircleAvatar( radius: 18, backgroundColor: colorScheme.secondaryContainer, backgroundImage: NetworkImage('$baseUrl/uploads/pp.png'), onBackgroundImageError: (e,s) => print("Post avatar network error ($baseUrl/uploads/pp.png): $e"), ), ),
                    const SizedBox(width: 10),
                    Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ GestureDetector( onTap: () => _navigateToProfile(username: postUsername), child: Text( postUsername, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis, ), ), if (postLocation != null && postLocation.isNotEmpty) Text( postLocation, style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor), maxLines: 1, overflow: TextOverflow.ellipsis, ), ], ), ),
                    IconButton( icon: Icon(Icons.more_vert, color: iconColor.withOpacity(0.7)), tooltip: 'Daha Fazla', onPressed: () { /* TODO: Options Menu */ }, ),
                   ],
                 ),
               ),
               // 2. Post Image (Handles null imageUrl)
              if (postImageUrl != null && postImageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 1.0, // Square aspect ratio for image
                  child: Container(
                    color: theme.dividerColor, // Background while loading
                    child: FadeInImage.assetNetwork(
                       placeholder: postPlaceholderIcon, // Local asset placeholder
                       // Construct full image URL if it's a relative path from backend uploads
                       image: (postImageUrl != null && postImageUrl.startsWith('/uploads/'))
                           ? '${_apiService.baseUrl.replaceAll('/api', '')}$postImageUrl' // Prepend backend server base URL
                           : postImageUrl ?? '', // Use as is (should be full URL or null)
                       fit: BoxFit.cover,
                       imageErrorBuilder: (context, error, stackTrace) => Center(child: Image.asset(_notFoundImage, fit: BoxFit.contain, width: 100, height: 100, color: theme.hintColor)),
                       placeholderErrorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 50, color: theme.hintColor)),
                     ),
                   ),
                 ),
                // 3. Action Buttons
               Padding( // ... (Action Buttons structure remains the same) ...
                 padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
                 child: Row(
                   children: [
                     IconButton( icon: Image.asset( isLiked ? likeRedIcon : likeIcon, width: 26, height: 26, color: likeColor, ), tooltip: 'Beğen', onPressed: () => _toggleLike(index), ), // Calls updated toggleLike
                    IconButton( icon: Image.asset( commentIcon, width: 26, height: 26, color: iconColor, ), tooltip: 'Yorum Yap', onPressed: () { /* TODO: Navigate/Open Comments */ }, ),
                    // IconButton( icon: Image.asset( sendIcon, width: 26, height: 26, color: iconColor, ), tooltip: 'Gönder', onPressed: () { /* TODO: Share Action */ }, ), // Optional Share
                    const Spacer(),
                    IconButton( icon: Image.asset( isBookmarked ? bookmarkTappedIcon : bookmarkBlackIcon, width: 26, height: 26, color: bookmarkColor, ), tooltip: 'Kaydet', onPressed: () => _toggleBookmark(index), ), // Calls updated toggleBookmark
                  ],
                ),
              ),
              // 4. Post Details (Likes, Caption, Comments, Timestamp)
              Padding( // ... (Post Details structure remains the same) ...
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (likeCount > 0) Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text( '$likeCount beğenme', style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold))),
                    if (postCaption.isNotEmpty) Padding( padding: const EdgeInsets.only(bottom: 4.0), child: RichText( text: TextSpan( style: theme.textTheme.bodyMedium?.copyWith(color: textColor, height: 1.3), children: [ TextSpan(text: '$postUsername ', style: const TextStyle(fontWeight: FontWeight.bold), recognizer: TapGestureRecognizer()..onTap = () => _navigateToProfile(username: postUsername)), TextSpan(text: postCaption), ], ), maxLines: 2, overflow: TextOverflow.ellipsis, ), ),
                    if (commentCount > 0) Padding( padding: const EdgeInsets.only(bottom: 4.0), child: InkWell( onTap: (){ /* TODO: Show Comments */ }, child: Text( commentCount == 1 ? '1 yorumu gör' : '$commentCount yorumun tümünü gör', style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor) ), ), ),
                    Text( timestamp, style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

} // End of _HomePageState
