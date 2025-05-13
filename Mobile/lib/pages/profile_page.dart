// lib/pages/profile_page.dart
import 'dart:convert'; // JSON dönüşümleri için gerekli.
import 'package:flutter/material.dart'; // Flutter Material Design widget'ları.
import 'package:provider/provider.dart'; // Provider importu <--- EKLENDİ
import 'package:solara/services/user_state.dart'; // UserState importu <--- EKLENDİ
// import 'package:http/http.dart' as http; // HTTP istekleri yapmak için. // Removed http import
import 'package:solara/services/api_service.dart'; // ApiService importu <--- EKLENDİ
import 'package:flutter/gestures.dart'; // TapGestureRecognizer importu <--- EKLENDİ
import 'package:solara/pages/single_post_page.dart'; // SinglePostPage importu <--- EKLENDİ
import 'package:solara/pages/comments_page.dart'; // Import CommentsPage <--- ADDED
import 'package:solara/constants/api_constants.dart' show ApiEndpoints, defaultAvatar; // Import ApiEndpoints and defaultAvatar <--- COMBINED IMPORTS

// Proje adınız farklıysa 'solara' kısmını değiştirin.
import 'package:solara/pages/widgets/sliver_app_bar_delegate.dart'; // Sabit kalan AppBar (TabBar için) delegate'i.

// ProfilePage: Kullanıcı profilini gösteren Stateful widget.
class ProfilePage extends StatefulWidget {
  // Görüntülenecek profilin kullanıcı adı.
  final String username;

  // Kurucu metot: username parametresi zorunludur.
  const ProfilePage({required this.username, super.key});

  @override
  // State nesnesini oluşturur.
  State<ProfilePage> createState() => _ProfilePageState();
}

// _ProfilePageState: ProfilePage'in durumunu yöneten sınıf.
// SingleTickerProviderStateMixin: TabController animasyonları için gerekli.
class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  // Sekmeleri (Tab) yönetmek için kontrolcü.
  late TabController _tabController;
  // Veri yüklenirken true olur, arayüzde yüklenme göstergesi gösterir.
  bool _isLoading = true;
  // API'den gelen profil verilerini tutan Map.
  Map<String, dynamic>? _profileData;
  // API veya işlem hatası mesajını tutar.
  String? _errorMessage;
  // Takip durumunu tutan state değişkeni.
  bool _isFollowing = false; // Added state for follow status
  // Kullanıcının gönderilerini tutan liste.
  List<Map<String, dynamic>> _userPosts = []; // Removed final and changed type
  // Etiketlenen gönderileri tutan geçici liste.
  final List<String> _taggedPosts = List.generate(3, (i) => "Tagged ${i+1}"); // Keep as is for now
  // TODO: Gerçek giriş yapmış kullanıcı kontrolü ile değiştirin.
  // Geçici olarak giriş yapmış kullanıcı adı.
  // final String _loggedInUsername = "soner1179"; // Will use UserState

  @override
  void initState() {
    super.initState();
    // TabController'ı başlat (2 sekme var: Gönderiler, Etiketlenenler).
    _tabController = TabController(length: 2, vsync: this); // <-- UPDATED length to 2
    // Profil verilerini çekmek için API isteğini başlat.
    _fetchProfileData();
  }

  @override
  void dispose() {
    // Widget ağaçtan kaldırıldığında TabController'ı temizle.
    _tabController.dispose();
    super.dispose();
  }

  // Asenkron olarak profil verilerini çeken fonksiyon.
  Future<void> _fetchProfileData() async {
    // Yüklenme durumunu başlat ve önceki hata mesajını temizle.
    setState(() { _isLoading = true; _errorMessage = null; });

    final apiService = ApiService(); // Create an instance of ApiService
    // Use the new endpoint to fetch user data by username
    final String endpoint = 'users/${widget.username}';

    try {
      final data = await apiService.get(endpoint);

      if (!mounted) return;

      setState(() {
        _profileData = Map<String, dynamic>.from(data); // Cast dynamic to Map
        // ----> BURAYA EKLEYİN <----
        print("Backend'den gelen profile_picture_url: ${_profileData?['profile_picture_url']}");
        // ----> EKLEME SONU <----
        // Initialize _isFollowing based on profile data (assuming backend provides 'is_following')
        _isFollowing = _profileData?['is_following'] ?? false;
        _isLoading = false; // Yüklenme durumunu bitir.
        // The backend should now return the correct username, but keep fallback just in case
        if (_profileData != null && _profileData!['username'] == null) {
           _profileData!['username'] = widget.username; // Parametre olarak gelen adı kullan.
        }
        // Fetch user posts after profile data is loaded
        if (_profileData != null && _profileData!['user_id'] != null) {
          _fetchUserPosts(_profileData!['user_id']);
        }
      });

    } catch (e) {
       if (!mounted) return; // Widget kontrolü.
       // Arayüzü güncelle: Genel hata mesajı ata ve yüklenmeyi bitir.
      setState(() {
         _errorMessage = 'Profil verisi alınamadı: ${e.toString()}'; // Use error message from exception
         _isLoading = false;
         print('Profil Çekme Hatası: $e'); // Hatayı konsola yazdır.
      });
    }
  }

  // Kullanıcıya özel gönderileri çekmek için fonksiyon.
  Future<void> _fetchUserPosts(int userId) async {
    print("Kullanıcı için gönderiler çekiliyor: $userId");
    final apiService = ApiService();
    final String endpoint = 'users/$userId/posts';

    try {
      final List<dynamic> data = await apiService.get(endpoint);

      if (!mounted) return;

      setState(() {
        _userPosts = List<Map<String, dynamic>>.from(data.map((post) {
          // Mapping similar to home_page.dart
          // Ensure ApiService instance is available or ApiEndpoints.baseUrl is static and accessible
          final String serverBase = ApiEndpoints.baseUrl.replaceAll('/api', '');

          String? authorAvatarUrlProcessed;
          final String? backendAuthorAvatarPath = post['profile_picture_url'] as String?;
          if (backendAuthorAvatarPath != null && backendAuthorAvatarPath.isNotEmpty) {
            if (backendAuthorAvatarPath.startsWith('/uploads/')) {
              authorAvatarUrlProcessed = '$serverBase$backendAuthorAvatarPath';
            } else if (backendAuthorAvatarPath.startsWith('http')) {
              authorAvatarUrlProcessed = backendAuthorAvatarPath;
            } else {
              authorAvatarUrlProcessed = defaultAvatar; // Fallback if format is unexpected
            }
          } else {
            authorAvatarUrlProcessed = defaultAvatar;
          }
          
          String? postImageUrlProcessed;
          final String? backendPostImagePath = post['image_url'] as String?; // Assuming 'image_url' from backend
          if (backendPostImagePath != null && backendPostImagePath.isNotEmpty) {
            if (backendPostImagePath.startsWith('/uploads/')) {
              postImageUrlProcessed = '$serverBase$backendPostImagePath';
            } else if (backendPostImagePath.startsWith('http')) {
              postImageUrlProcessed = backendPostImagePath;
            }
            // If not /uploads/ and not http, it might be an error or an unexpected format.
            // For now, we let it pass, and the FadeInImage.assetNetwork will try to load it.
            // If it's an asset path, it won't work with assetNetwork unless it's a full URL.
            // This part might need adjustment based on actual backend response for post images.
            else {
                postImageUrlProcessed = backendPostImagePath; // Or handle as error/default
            }
          }


          return {
            'id': post['post_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), // Ensure ID is string
            'user_id': post['user_id'],
            'username': post['username'] ?? 'unknown_user',
            // 'avatarUrl': authorAvatarUrlProcessed, // This key is used in home_page, profile_page uses profile_picture_url directly in _buildPostsGrid
            'profile_picture_url': authorAvatarUrlProcessed, // Keep this key as _buildPostsGrid expects it for the author
            'imageUrl': postImageUrlProcessed, // For the main post image
            'caption': post['content_text'] ?? '', // Assuming 'content_text' from backend
            'likeCount': post['likes_count'] ?? 0,
            'commentCount': post['comments_count'] ?? 0,
            'isLiked': post['is_liked_by_current_user'] ?? false,
            'isBookmarked': post['is_saved_by_current_user'] ?? false,
            'timestamp': _formatTimestamp(post['created_at']),
            'location': post['location'], // Assuming backend might provide location
          };
        }));
        print("Kullanıcı gönderileri başarıyla çekildi ve maplendi: ${_userPosts.length} gönderi");
      });
    } catch (e) {
      if (!mounted) return;
      print('Kullanıcı gönderileri çekme/mapleme hatası: $e');
      // Optionally show a SnackBar or update an error state
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcı gönderileri yüklenemedi: ${e.toString()}')),
      );
    }
  }

  // Helper function to format timestamp (Copied from home_page.dart)
  String _formatTimestamp(String? apiTimestamp) {
    if (apiTimestamp == null) return 'Az önce'; // Turkish for 'Just now'
    try {
      DateTime postTime = DateTime.parse(apiTimestamp).toLocal();
      Duration diff = DateTime.now().difference(postTime);
      if (diff.inDays > 7) return '${postTime.day}.${postTime.month}.${postTime.year}';
      if (diff.inDays >= 1) return '${diff.inDays}g önce'; // Turkish for 'd ago'
      if (diff.inHours >= 1) return '${diff.inHours}s önce'; // Turkish for 'h ago'
      if (diff.inMinutes >= 1) return '${diff.inMinutes}d önce'; // Turkish for 'm ago'
      return 'Az önce';
    } catch (e) {
      print("Timestamp formatlama hatası: $e");
      return apiTimestamp; // Hata durumunda orijinalini döndür
    }
  }

  // Function to toggle like status (Copied from home_page.dart)
  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _userPosts.length || !mounted) return;

    final post = _userPosts[index];
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
      final apiService = ApiService(); // Create instance
      if (post['isLiked']) {
        // If UI shows liked, call like API
        await apiService.likePost(postId, currentUserId);
        print('API: Post $postId liked successfully.');
      } else {
        // If UI shows not liked, call unlike API
        await apiService.unlikePost(postId, currentUserId);
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

  // Function to toggle bookmark status (Copied from home_page.dart)
  Future<void> _toggleBookmark(int index) async {
    if (index < 0 || index >= _userPosts.length || !mounted) return;

    final post = _userPosts[index];
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
       final apiService = ApiService(); // Create instance
       if (post['isBookmarked']) {
        // If UI shows bookmarked, call bookmark API
        await apiService.bookmarkPost(postId, currentUserId);
        print("API: Post $postId bookmarked successfully.");
      } else {
         // If UI shows not bookmarked, call unbookmark API
        await apiService.unbookmarkPost(postId, currentUserId);
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


  @override
  // Widget'ın arayüzünü oluşturan metot.
  Widget build(BuildContext context) {
    // Görüntülenen profilin, giriş yapmış kullanıcıya ait olup olmadığını kontrol et.
    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];
    final bool isCurrentUserProfile = currentUserId != null && _profileData?['user_id'] == currentUserId;


    // Temel sayfa yapısı.
    return Scaffold(
      backgroundColor: Colors.white, // Arka plan rengi beyaz.
      // Üst uygulama çubuğu.
      appBar: AppBar(
        backgroundColor: Colors.white, // Arka plan beyaz.
        elevation: 0, // Gölge yok.
        // Başlık: Yükleniyorsa "Yükleniyor...", yüklendiyse kullanıcı adı.
        title: Text(
          _isLoading ? 'Yükleniyor...' : (_profileData?['username'] ?? widget.username),
          style: const TextStyle( color: Colors.black87, fontWeight: FontWeight.bold,),
        ),
        // Geri butonu.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          tooltip: 'Geri',
          onPressed: () => Navigator.pop(context), // Önceki sayfaya dön.
        ),
        // Sağdaki eylem ikonları (Seçenekler menüsü).
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
             tooltip: 'Seçenekler',
            onPressed: () {
               print("Profil Seçenekleri Tıklandı (TODO)");
               // TODO: Kendi profilin için ayarlar/çıkış, başkası için şikayet/engelle göster.
            },
          ),
        ],
      ),
      // Sayfa gövdesi: Yüklenme, hata veya profil içeriğini gösterir.
      body: _isLoading
          // Yükleniyorsa: Ortada dönen bir ilerleme göstergesi.
          ? const Center(child: CircularProgressIndicator())
          // Hata varsa: Ortada hata mesajını göster.
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Hata: $_errorMessage', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
              // Profil verisi boşsa (API'den null döndüyse): Ortada "Profil bulunamadı" mesajı.
              : _profileData == null
                  ? const Center(child: Text('Profil bulunamadı.'))
                  // Veri başarıyla yüklendiyse: İç içe kaydırılabilir görünüm (NestedScrollView).
                  : NestedScrollView(
                      // Üstte sabit kalmayan (kaydırılabilen) bölümü tanımlar.
                       headerSliverBuilder:(context, innerBoxIsScrolled) => [
                         // Profil başlığı, istatistikleri ve butonları içeren bölüm.
                         SliverToBoxAdapter(
                           child: Column(
                             children: [
                               _buildProfileHeader(_profileData!), // Profil başlığı (avatar, isim, bio).
                               _buildProfileStats(_profileData!), // İstatistikler (gönderi, takipçi, takip).
                               _buildProfileButtons(isCurrentUserProfile, _profileData!), // Eylem butonları (Düzenle/Takip Et, Mesaj).
                              ],
                            ),
                         ),
                         // Üstte sabit kalan (pinned) bölüm (Sekme çubuğu).
                         SliverPersistentHeader(
                            // Özel delegate'imizi kullanarak sekme çubuğunu sabitler.
                            delegate: SliverAppBarDelegate(
                              TabBar(
                                controller: _tabController, // Sekme kontrolcüsü.
                                labelColor: Colors.black, // Seçili sekme rengi.
                                unselectedLabelColor: Colors.grey.shade500, // Seçili olmayan sekme rengi.
                                indicatorColor: Colors.black, // Sekme altı çizgi rengi.
                                indicatorWeight: 2.0, // Sekme altı çizgi kalınlığı.
                                // Sekmeler (ikonlar).
                                tabs: const [
                                  Tab(icon: Icon(Icons.grid_on_outlined)), // Gönderiler.
                                  // Tab(icon: Icon(Icons.bookmark_border_outlined)), // <-- REMOVED Saved Tab
                                  Tab(icon: Icon(Icons.person_pin_outlined)), // Etiketlenenler.
                                ],
                              ),
                            ),
                            pinned: true, // Yukarı kaydırıldığında sabit kalmasını sağlar.
                          ),
                       ],
                      // Sekme çubuğuna karşılık gelen içerik görünümleri.
                      body: TabBarView(
                        controller: _tabController, // Sekme kontrolcüsü.
                        children: [
                          _buildPostsGrid(_userPosts), // Pass the fetched _userPosts
                          // _buildSavedGrid(_savedPosts), // <-- REMOVED Saved Grid View
                          _buildTaggedGrid(_taggedPosts), // Etiketlenen gönderiler (ızgara görünümü).
                        ],
                      ),
                    ),
    );
  }

  // --- Profil Sayfası Yardımcı Widget'ları ---

  String _getImageUrl(String? relativeOrAbsoluteUrl) {
    if (relativeOrAbsoluteUrl == null || relativeOrAbsoluteUrl.isEmpty) {
      // ----> BURAYA BİR LOG EKLEYELİM <----
      print("_getImageUrl: relativeOrAbsoluteUrl null veya boş, defaultAvatar kullanılacak: $defaultAvatar");
      return defaultAvatar; // Fallback to default if no URL
    }
    if (relativeOrAbsoluteUrl.startsWith('http')) {
      return relativeOrAbsoluteUrl; // Already an absolute URL
    }
    // Assuming ApiEndpoints.baseUrl is like "http://server.com/api"
    // and relativeOrAbsoluteUrl is like "/uploads/image.png"
    // We want "http://server.com/uploads/image.png"
    final serverBase = ApiEndpoints.baseUrl.replaceAll('/api', '');
    return '$serverBase$relativeOrAbsoluteUrl';
  }

  // Helper widget to decide whether to use NetworkImage or AssetImage
  Widget _buildImageWidget(Map<String, dynamic> profileData) {
    final imageUrl = profileData['profile_picture_url'] as String?; // Cast to String?
    final String finalImageUrlToShow;
    bool isNetworkImage = false;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        finalImageUrlToShow = imageUrl;
        isNetworkImage = true;
      } else if (imageUrl.startsWith('/uploads/')) {
        final serverBase = ApiEndpoints.baseUrl.replaceAll('/api', '');
        finalImageUrlToShow = '$serverBase$imageUrl';
        isNetworkImage = true;
      } else {
        print("_buildImageWidget: Invalid format for imageUrl ('$imageUrl'), using defaultAvatar.");
        finalImageUrlToShow = defaultAvatar;
        isNetworkImage = false; // It's an asset path
      }
    } else {
      print("_buildImageWidget: imageUrl is null or empty, using defaultAvatar.");
      finalImageUrlToShow = defaultAvatar;
      isNetworkImage = false; // It's an asset path
    }

    if (isNetworkImage) {
      return FadeInImage.assetNetwork(
        placeholder: defaultAvatar, // Placeholder is always an asset
        image: finalImageUrlToShow,
        fit: BoxFit.cover,
        imageErrorBuilder: (context, error, stackTrace) {
          print('Error loading profile image (FadeInImage.assetNetwork) for $finalImageUrlToShow: $error');
          return Image.asset( // Fallback to defaultAvatar asset on network error
            defaultAvatar,
            fit: BoxFit.cover,
          );
        },
        placeholderErrorBuilder: (context, error, stackTrace) {
            print('Error loading placeholder asset (FadeInImage.assetNetwork): $error');
            return Icon(Icons.person, size: 42); // Fallback for placeholder itself
        },
      );
    } else {
      // finalImageUrlToShow here is expected to be an asset path (defaultAvatar)
      return Image.asset(
        finalImageUrlToShow,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading profile image (Image.asset) for $finalImageUrlToShow: $error');
          // Fallback if the default asset itself fails to load
          return Icon(Icons.person, size: 42); // Basic fallback icon
        },
      );
    }
  }

  // Profil başlığını (Avatar, İsim/Kullanıcı Adı, Bio) oluşturan widget.
  Widget _buildProfileHeader(Map<String, dynamic> profileData) {
    return Padding(
      padding: const EdgeInsets.all(16.0), // Dış boşluklar.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Öğeleri dikeyde ortala.
        children: [
          // Kullanıcı avatarı.
          CircleAvatar(
            radius: 45, // Dış çember yarıçapı (hafif renkli arka plan).
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.5),
            child: ClipOval( // Use ClipOval to ensure the image is circular
              child: SizedBox( // Use SizedBox to control the size
                width: 84, // 2 * radius
                height: 84, // 2 * radius
                child: _buildImageWidget(profileData), // Use the helper widget
              ),
            ),
          ),
          const SizedBox(width: 20), // Avatar ve metinler arasına boşluk.
          // İsim, kullanıcı adı ve bio'yu içeren bölüm.
          Expanded( // Kalan yatay alanı kapla.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Metinleri sola yasla.
              children: [
                // İsim (Backend 'name' kullanıyor, fallback sağla).
                Text(
                  profileData['name'] ?? profileData['username'] ?? widget.username,
                  style: const TextStyle( fontWeight: FontWeight.bold, fontSize: 18,),
                ),
                 const SizedBox(height: 4), // İsim ve kullanıcı adı arasına boşluk.
                 // Kullanıcı adını '@' ile göster.
                 Text(
                   '@${profileData['username'] ?? widget.username}',
                   style: const TextStyle( color: Colors.grey, fontSize: 14,),
                 ),
                const SizedBox(height: 8), // Kullanıcı adı ve bio arasına boşluk.
                // Bio (varsa ve boş değilse göster).
                if (profileData['bio'] != null && profileData['bio'].isNotEmpty)
                  Text(
                    profileData['bio'],
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3, overflow: TextOverflow.ellipsis, // En fazla 3 satır, taşarsa ...
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

   // Profil istatistiklerini (Gönderi, Takipçi, Takip, Solar Puanı) oluşturan widget.
   Widget _buildProfileStats(Map<String, dynamic> profileData) {
    // Use the fetched counts from profileData
    final int postCount = profileData['post_count'] ?? 0; // Assuming backend adds post_count
    final int followersCount = profileData['followers_count'] ?? 0;
    final int followingCount = profileData['following_count'] ?? 0;
    final int solarPoints = profileData['solar_points'] ?? 0; // Assuming backend adds solar_points

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Yatay ve dikey dış boşluklar.
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12), // İç dikey boşluk.
        // Üst ve alt kenarlık ekler.
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200), bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Öğeleri yatayda eşit aralıklarla dağıt.
          children: [
            _buildStatItem(postCount.toString(), 'Gönderi'),
            _buildStatItem(followersCount.toString(), 'Takipçi'),
            _buildStatItem(followingCount.toString(), 'Takip'),
            _buildStatItem(solarPoints.toString(), 'Solara Puanı'),
          ],
        ),
      ),
    );
  }

  // Tek bir istatistik öğesini (Sayı ve Etiket) oluşturan widget.
  Widget _buildStatItem(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Dikeyde minimum yer kapla.
      children: [
        // Sayı (kalın).
        Text( count, style: const TextStyle( fontWeight: FontWeight.bold, fontSize: 16,),),
        const SizedBox(height: 2), // Sayı ve etiket arasına boşluk.
        // Etiket (gri).
        Text( label, style: const TextStyle( color: Colors.grey, fontSize: 12,),),
      ],
    );
  }

  // Profil eylem butonlarını (Profili Düzenle / Takip Et/Takip Ediliyor, Mesaj Gönder) oluşturan widget.
  Widget _buildProfileButtons(bool isCurrentUserProfile, Map<String, dynamic> profileData) {
    // _isFollowing state'i kullanılır. Placeholder kaldırıldı.

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Dış boşluklar.
      child: Row(
        children: isCurrentUserProfile // Eğer bu, giriş yapmış kullanıcının profili ise:
            // Sadece "Profili Düzenle" butonu gösterilir.
            ? [
                Expanded( // Butonun satırı kaplamasını sağlar.
                  child: OutlinedButton( // Kenarlıklı buton.
                    onPressed: () { print("Profili Düzenle Tıklandı (TODO)"); }, // Tıklanma eylemi (TODO).
                    style: OutlinedButton.styleFrom( // Buton stili.
                      foregroundColor: Colors.black, // Metin rengi siyah.
                      side: BorderSide(color: Colors.grey.shade400), // Kenarlık rengi gri.
                       padding: const EdgeInsets.symmetric(vertical: 10), // İç dikey boşluk.
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),), // Köşeleri yuvarlat.
                    ), child: const Text('Profili Düzenle'), // Buton metni.
                  ),
                ),
              ]
            // Eğer bu, başka bir kullanıcının profili ise:
            // "Takip Et/Takip Ediliyor" ve "Mesaj Gönder" butonları gösterilir.
            : [
                 Expanded( // Butonun mevcut alanı paylaşmasını sağlar.
                  child: ElevatedButton( // Dolgulu buton (Takip Et/Ediliyor).
                    onPressed: _toggleFollow, // Call _toggleFollow method
                     style: ElevatedButton.styleFrom( // Buton stili.
                       // Takip ediliyorsa beyaz arka plan, edilmiyorsa tema rengi.
                       backgroundColor: _isFollowing ? Colors.white : Theme.of(context).primaryColor,
                       // Takip ediliyorsa siyah metin, edilmiyorsa beyaz metin.
                       foregroundColor: _isFollowing ? Colors.black : Colors.white,
                       // Takip ediliyorsa kenarlık ekle.
                       side: _isFollowing ? BorderSide(color: Colors.grey.shade400) : null,
                       padding: const EdgeInsets.symmetric(vertical: 10), // İç dikey boşluk.
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Köşeleri yuvarlat.
                       elevation: _isFollowing ? 0 : 2, // Takip edilmiyorsa hafif gölge.
                    ),
                    // Takip durumuna göre buton metni.
                    child: Text(_isFollowing ? 'Takip Ediliyor' : 'Takip Et'),
                  ),
                ),
                const SizedBox(width: 8), // İki buton arasına boşluk.
                Expanded( // Butonun mevcut alanı paylaşmasını sağlar.
                   child: OutlinedButton( // Kenarlıklı buton (Mesaj Gönder).
                    onPressed: () { print("Mesaj Tıklandı (TODO)"); }, // Tıklanma eylemi (TODO).
                    style: OutlinedButton.styleFrom( // Buton stili.
                       foregroundColor: Colors.black, // Metin rengi siyah.
                       side: BorderSide(color: Colors.grey.shade400), // Kenarlık rengi gri.
                       padding: const EdgeInsets.symmetric(vertical: 10), // İç dikey boşluk.
                       shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8)), // Köşeleri yuvarlat.
                    ), child: const Text('Mesaj Gönder'), // Buton metni.
                  ),
                ),
            ],
      ),
    );
  }

  // Kullanıcının gönderilerini ızgara (Grid) görünümünde oluşturan widget.
  Widget _buildPostsGrid(List<Map<String, dynamic>> posts) { // Changed list type
     // Eğer gönderi yoksa ortada bir mesaj göster.
     if (posts.isEmpty) return const Center(child: Text("Henüz gönderi yok."));

     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;

     // Use a ListView for detailed post view, not GridView
     return ListView.builder(
       padding: const EdgeInsets.only(bottom: 10), // Padding below list
       itemCount: posts.length,
       itemBuilder: (context, index) {
         final postData = posts[index];
         // Extract post data (use null checks and defaults)
         final String postId = postData['id'] ?? 'error_id_$index';
         final String postUsername = postData['username'] ?? 'bilinmeyen';
         final String? postLocation = postData['location']; // Optional field
         // final String authorAvatarUrl = postData['profile_picture_url'] ?? defaultAvatar; // Use profile_picture_url for author // ESKİ KULLANIM
         final String? authorRawAvatarUrl = postData['profile_picture_url'] as String?; // YENİ: Null olabilen ham URL
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

         // Build Post Card (Copied from home_page.dart)
         return Container(
           margin: const EdgeInsets.symmetric(vertical: 8.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // 1. Post Header
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                 child: Row(
                   children: [
                     GestureDetector(
                       onTap: () { /* TODO: Navigate to profile of postUsername */ },
                       child: CircleAvatar(
                         radius: 18,
                         backgroundColor: colorScheme.secondaryContainer,
                         child: ClipOval( // İçeriğin dairesel olmasını garantile
                           child: SizedBox(
                             width: 36, // CircleAvatar radius * 2
                             height: 36,
                             child: _buildImageWidget({'profile_picture_url': authorRawAvatarUrl}), // YENİ: _buildImageWidget KULLAN
                           ),
                         ),
                         // onBackgroundImageError artık _buildImageWidget içinde ele alınıyor
                       ),
                     ),
                     const SizedBox(width: 10),
                     Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ GestureDetector( onTap: () { /* TODO: Navigate to profile of postUsername */ }, child: Text( postUsername, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis, ), ), if (postLocation != null && postLocation.isNotEmpty) Text( postLocation, style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor), maxLines: 1, overflow: TextOverflow.ellipsis, ), ], ), ),
                     // IconButton( icon: Icon(Icons.more_vert, color: iconColor.withOpacity(0.7)), tooltip: 'Daha Fazla', onPressed: () { /* TODO: Options Menu */ }, ), // OLD MENU ICON
                     PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: iconColor.withOpacity(0.7)),
                        tooltip: 'Daha Fazla',
                        onSelected: (String value) {
                          if (value == 'toggle_bookmark') {
                            _toggleBookmark(index);
                          } else if (value == 'read_aloud') {
                            // TODO: Implement Sesli Oku functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sesli Oku özelliği yakında.')),
                            );
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'toggle_bookmark',
                            child: Text(isBookmarked ? 'Kaydetmeyi Kaldır' : 'Kaydet'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'read_aloud',
                            child: Text('Sesli Oku'),
                          ),
                        ],
                      ),
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
                        placeholder: 'assets/images/post_placeholder.png', // Local asset placeholder
                        // Construct full image URL if it's a relative path from backend uploads
                        image: postImageUrl, // Already processed in _fetchUserPosts
                        fit: BoxFit.cover,
                        imageErrorBuilder: (context, error, stackTrace) => Center(child: Image.asset('assets/images/not-found.png', fit: BoxFit.contain, width: 100, height: 100, color: theme.hintColor)),
                        placeholderErrorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 50, color: theme.hintColor)),
                      ),
                    ),
                  ),
                 // 3. Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
                  child: Row(
                    children: [
                      IconButton( icon: Image.asset( isLiked ? 'assets/images/like(red).png' : 'assets/images/like.png', width: 26, height: 26, color: likeColor, ), tooltip: 'Beğen', onPressed: () => _toggleLike(index), ), // Calls _toggleLike
                     IconButton( icon: Image.asset( 'assets/images/comment.png', width: 26, height: 26, color: iconColor, ), tooltip: 'Yorum Yap', onPressed: () { // Navigate to CommentsPage
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => CommentsPage(postId: int.parse(postId)), // Pass the post ID
                         ),
                       );
                     }, ),
                     // IconButton( icon: Image.asset( 'assets/images/send.png', width: 26, height: 26, color: iconColor, ), tooltip: 'Gönder', onPressed: () { /* TODO: Share Action */ }, ), // Optional Share
                     const Spacer(),
                     // IconButton( icon: Image.asset( isBookmarked ? 'assets/images/bookmark(tapped).png' : 'assets/images/bookmark(black).png', width: 26, height: 26, color: bookmarkColor, ), tooltip: 'Kaydet', onPressed: () => _toggleBookmark(index), ), // Calls _toggleBookmark // REMOVED
                   ],
                 ),
               ),
               // 4. Post Details (Likes, Caption, Comments, Timestamp)
               Padding(
                 padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     if (likeCount > 0) Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text( '$likeCount beğenme', style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold))),
                     if (postCaption.isNotEmpty) Padding( padding: const EdgeInsets.only(bottom: 4.0), child: RichText( text: TextSpan( style: theme.textTheme.bodyMedium?.copyWith(color: textColor, height: 1.3), children: [ TextSpan(text: '$postUsername ', style: const TextStyle(fontWeight: FontWeight.bold), recognizer: TapGestureRecognizer()..onTap = () { /* TODO: Navigate to profile */ }), TextSpan(text: postCaption), ], ), maxLines: 2, overflow: TextOverflow.ellipsis, ), ),
                     if (commentCount > 0) Padding( padding: const EdgeInsets.only(bottom: 4.0), child: InkWell( onTap: (){ // Navigate to CommentsPage when tapping comment count
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => CommentsPage(postId: int.parse(postId)), // Pass the post ID
                         ),
                       );
                     }, child: Text( commentCount == 1 ? '1 yorumu gör' : '$commentCount yorumun tümünü gör', style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor) ), ), ),
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

  // Kaydedilen gönderileri ızgara görünümünde oluşturan widget. <-- REMOVED this function

  // Etiketlenen gönderileri ızgara görünümünde oluşturan widget.
  Widget _buildTaggedGrid(List<String> taggedPosts) {
     // Eğer etiketlenen gönderi yoksa ortada bir mesaj göster.
     if (taggedPosts.isEmpty) return const Center(child: Text("Etiketlenen gönderi yok."));
     // Izgara görünümü.
    return GridView.builder(
       padding: const EdgeInsets.all(1.0), // Izgara kenarlarında hafif boşluk.
       // Izgara düzeni: Sabit 3 sütunlu, öğeler arası boşluklu.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 3, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5,),
      itemCount: taggedPosts.length, // Izgara öğe sayısı.
       shrinkWrap: true, // İçeriğe göre boyutlan.
       physics: const NeverScrollableScrollPhysics(), // Kaydırmayı engelle.
       // Her bir ızgara öğesini oluşturur.
      itemBuilder: (context, index) {
        // Placeholder: Farklı renkte bir kutu içinde gönderi adını gösterir.
        return Container( color: Colors.teal[100], child: Center( child: Text(taggedPosts[index]),),);
      },
    );
  }

  // --- Follow/Unfollow Logic ---
  Future<void> _toggleFollow() async {
    if (_profileData == null || _profileData!['user_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil bilgisi yüklenemedi.')));
      return;
    }

    final userState = Provider.of<UserState>(context, listen: false);
    final currentUserId = userState.currentUser?['user_id'];

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem için giriş yapmalısınız.')));
      // Optionally navigate to login page
      return;
    }

    final int followedId = _profileData!['user_id'];
    final bool wasFollowing = _isFollowing;
    int currentFollowersCount = _profileData!['followers_count'] ?? 0;

    // Optimistic UI update
    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _profileData!['followers_count'] = currentFollowersCount + 1;
      } else {
        _profileData!['followers_count'] = currentFollowersCount > 0 ? currentFollowersCount - 1 : 0;
      }
    });

    try {
      final apiService = ApiService();
      if (_isFollowing) {
        // followerId is currentUserId, followedId is profile's user_id
        await apiService.followUser(currentUserId, followedId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_profileData!['username']} takip ediliyor.')));
      } else {
        await apiService.unfollowUser(currentUserId, followedId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_profileData!['username']} takipten çıkarıldı.')));
      }
      // Optionally re-fetch profile data to get confirmed follower count and status
      // _fetchProfileData(); // This might be too much, or backend could return updated counts
    } catch (e) {
      // Revert UI on error
      setState(() {
        _isFollowing = wasFollowing;
        _profileData!['followers_count'] = currentFollowersCount; // Revert count
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: ${e.toString()}')));
      print('Follow/Unfollow Error: $e');
    }
  }
}
