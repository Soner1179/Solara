// lib/pages/profile_page.dart
import 'dart:convert'; // JSON dönüşümleri için gerekli.
import 'package:flutter/material.dart'; // Flutter Material Design widget'ları.
import 'package:provider/provider.dart'; // Provider importu <--- EKLENDİ
import 'package:solara/services/user_state.dart'; // UserState importu <--- EKLENDİ
import 'package:solara/services/api_service.dart'; // ApiService importu <--- EKLENDİ
import 'package:flutter/gestures.dart'; // TapGestureRecognizer importu <--- EKLENDİ
import 'package:solara/pages/single_post_page.dart'; // SinglePostPage importu <--- EKLENDİ
import 'package:solara/pages/comments_page.dart'; // Import CommentsPage <--- ADDED
import 'package:solara/pages/followers_list_page.dart'; // Import FollowersListPage
import 'package:solara/pages/following_list_page.dart'; // Import FollowingListPage
import 'package:solara/constants/api_constants.dart' show ApiEndpoints, defaultAvatar; // Import ApiEndpoints and defaultAvatar <--- COMBINED IMPORTS

// Proje adınız farklıysa 'solara' kısmını değiştirin.
import 'package:solara/pages/widgets/sliver_app_bar_delegate.dart'; // Sabit kalan AppBar (TabBar için) delegate'i.
import 'package:solara/widgets/post_card.dart' hide defaultAvatar; // Import the new PostCard widget

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
  // Takip isteği gönderildi durumunu tutan state değişkeni.
  bool _followRequestSent = false; // Added state for follow request sent status
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

  // Zaman damgası formatlama (HomePage'den kopyalandı)
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
        // Initialize _followRequestSent based on profile data (assuming backend provides 'has_pending_request')
        _followRequestSent = _profileData?['has_pending_request'] ?? false; // Initialize with backend data

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

  // Kullanıcının gönderilerini çekmek için fonksiyon.
  Future<void> _fetchUserPosts(int userId) async { // Changed parameter to userId
    print("Kullanıcı için gönderiler çekiliyor: $userId");
    final apiService = ApiService();
    final String endpoint = 'users/$userId/posts'; // Use the endpoint with user_id

    print('[_fetchUserPosts] API call started for endpoint: $endpoint'); // Log start of API call

    try {
      final dynamic data = await apiService.get(endpoint); // Get the decoded data directly

      if (!mounted) return;

      if (data is List) {
         if (data.isNotEmpty) {
            print('[_fetchUserPosts] First post data received: ${data[0]}'); // Print the first post object
         } else {
            print('[_fetchUserPosts] Received empty list for user posts.');
         }
         // Map backend keys to PostCard expected keys
         final List<Map<String, dynamic>> mappedPosts = data.map<Map<String, dynamic>>((post) {
           return {
             'id': post['post_id']?.toString() ?? 'error_id_${UniqueKey().toString()}', // Ensure ID is string
             'user_id': post['user_id'],
             'username': post['username'] ?? 'unknown_user',
             'avatarUrl': post['profile_picture_url'], // Use backend key, _getImageUrl in PostCard handles URL construction
             'imageUrl': post['image_url'], // Use backend key, _getImageUrl in PostCard handles URL construction
             'caption': post['content_text'] ?? '',
             'likeCount': post['likes_count'] ?? 0, // Map likes_count to likeCount
             'commentCount': post['comments_count'] ?? 0, // Map comments_count to commentCount
             'isLiked': post['is_liked_by_current_user'] ?? false, // Map is_liked_by_current_user to isLiked
             'isBookmarked': post['is_saved_by_current_user'] ?? false, // Map is_saved_by_current_user to isBookmarked
             'timestamp': _formatTimestamp(post['created_at']), // Use backend key, and format it locally
             'location': post['location'], // Include location if available
           };
         }).toList();

         setState(() {
           _userPosts = mappedPosts; // Update _userPosts with mapped data
         });
      } else {
         print('[_fetchUserPosts] Unexpected data format for user posts: $data');
         // Handle unexpected format, maybe show an error message
         if (!mounted) return;
         setState(() {
            _errorMessage = 'Beklenmedik gönderi verisi formatı.';
            _isLoading = false; // Stop loading
         });
      }

    } catch (e) {
      if (!mounted) return;
      print('[_fetchUserPosts] Kullanıcı gönderileri çekme hatası: ${e.toString()}'); // Log error
      // Optionally show a SnackBar or update an error state for user posts specifically
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
            _buildStatItem(postCount.toString(), 'Gönderi', null), // No tap action for posts
            _buildStatItem(followersCount.toString(), 'Takipçi', () {
              print('Takipçi sayısı tıklandı!');
              if (_profileData != null && _profileData!['user_id'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FollowersListPage(userId: _profileData!['user_id']),
                  ),
                );
              }
            }),
            _buildStatItem(followingCount.toString(), 'Takip', () {
              print('Takip sayısı tıklandı!');
               if (_profileData != null && _profileData!['user_id'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FollowingListPage(userId: _profileData!['user_id']),
                  ),
                );
              }
            }),
            _buildStatItem(solarPoints.toString(), 'Solar Puanı', null), // No tap action for solar points
          ],
        ),
      ),
    );
  }

  // Tek bir istatistik öğesini (Sayı ve Etiket) oluşturan widget.
  Widget _buildStatItem(String count, String label, VoidCallback? onTap) {
    return GestureDetector(onTap: onTap, child: Column(
        mainAxisSize: MainAxisSize.max, // Dikeyde minimum yer kapla.
        children: [
          // Sayı (kalın).
          Text( count, style: const TextStyle( fontWeight: FontWeight.bold, fontSize: 16,),),
        const SizedBox(height: 2), // Sayı ve etiket arasına boşluk.
        // Etiket (gri).
        Text( label, style: const TextStyle( color: Colors.grey, fontSize: 12,),),
      ],
    ));
  }

  // Profil eylem butonlarını (Profili Düzenle / Takip Et/Takip Ediliyor, Mesaj Gönder) oluşturan widget.
  Widget _buildProfileButtons(bool isCurrentUserProfile, Map<String, dynamic> profileData) {
    // _isFollowing state'i kullanılır. Placeholder kaldırıldı.
    final bool isPrivate = profileData['is_private'] ?? false; // Get the privacy status

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
                       backgroundColor: (_isFollowing || _followRequestSent) ? Colors.white : Theme.of(context).primaryColor,
                       // Takip ediliyorsa siyah metin, edilmiyorsa beyaz metin.
                       foregroundColor: (_isFollowing || _followRequestSent) ? Colors.black : Colors.white,
                       // Takip ediliyorsa kenarlık ekle.
                       side: (_isFollowing || _followRequestSent) ? BorderSide(color: Colors.grey.shade400) : null,
                       padding: const EdgeInsets.symmetric(vertical: 10), // İç dikey boşluk.
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Köşeleri yuvarlat.
                       elevation: (_isFollowing || _followRequestSent) ? 0 : 2, // Takip edilmiyorsa hafif gölge.
                    ),
                    // Takip durumuna göre buton metni.
                    child: Text(
                      _isFollowing
                          ? 'Takip Ediliyor'
                          : _followRequestSent
                              ? 'İstek Gönderildi'
                              : 'Takip Et',
                    ),
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
     // Get current user ID
     final userState = Provider.of<UserState>(context, listen: false);
     final currentUserId = userState.currentUser?['user_id'];

     if (currentUserId == null) {
       // Handle the case where the user is not logged in, maybe show a message
       return const Center(child: Text("Gönderileri görmek için giriş yapın."));
     }

     // If gönderi yoksa ortada bir mesaj göster.
     if (posts.isEmpty) return const Center(child: Text("Henüz gönderi yok."));

     // Use a ListView for detailed post view, not GridView
     return ListView.builder(
       padding: const EdgeInsets.only(bottom: 10), // Padding below list
       itemCount: posts.length,
       itemBuilder: (context, index) {
         final postData = posts[index];
         // Use the new PostCard widget to render each post
         return PostCard(postData: postData, userId: currentUserId);
       },
     );
   }

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
    final bool isPrivate = _profileData!['is_private'] ?? false; // Get the privacy status
    int currentFollowersCount = _profileData!['followers_count'] ?? 0;
    final bool wasRequestSent = _followRequestSent; // Capture current request state

    // Optimistic UI update
    setState(() {
      if (isPrivate) {
        // If private, toggle the request sent status
        _followRequestSent = !wasRequestSent;
      } else {
        // If not private, toggle the follow status directly
        _isFollowing = !_isFollowing;
        if (_isFollowing) {
          _profileData!['followers_count'] = currentFollowersCount + 1;
        } else {
          _profileData!['followers_count'] = currentFollowersCount > 0 ? currentFollowersCount - 1 : 0;
        }
      }
    });

    try {
      final apiService = ApiService();
      if (isPrivate) {
        // If the account is private, send a follow request
        if (_followRequestSent) { // If UI now shows "Request Sent"
           // Assuming a new API call for sending requests
           // await apiService.sendFollowRequest(followedId); // Need to add this method to ApiService
           // The backend's follow endpoint now handles this, so call followUser
           await apiService.followUser(followedId);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_profileData!['username']} adlı kullanıcıya takip isteği gönderildi.')));
        } else {
           // If UI now shows "Follow" (meaning we are cancelling a request)
           // Need a way to cancel a pending request. This wasn't explicitly in the requirements
           // but is good practice. Let's assume a new API call for cancelling requests.
           // await apiService.cancelFollowRequest(followedId); // Need to add this method to ApiService
           // For now, we won't implement cancelling from the profile page.
           // Revert UI if this state is reached unexpectedly.
           setState(() {
             _followRequestSent = wasRequestSent; // Revert UI
           });
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takip isteği iptali şu anda desteklenmiyor.')));
        }
      } else {
        // If the account is not private, proceed with direct follow/unfollow
        if (_isFollowing) {
          // followerId is currentUserId, followedId is profile's user_id
          await apiService.followUser(followedId); // Use the updated followUser
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_profileData!['username']} takip ediliyor.')));
        } else {
          await apiService.unfollowUser(followedId); // Use the updated unfollowUser
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_profileData!['username']} takipten çıkıldı.')));
        }
      }
    } catch (e) {
      // Revert UI on error
      setState(() {
        if (isPrivate) {
           _followRequestSent = wasRequestSent; // Revert request state
        } else {
          _isFollowing = wasFollowing;
          _profileData!['followers_count'] = currentFollowersCount; // Revert count
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: ${e.toString()}')));
      print('Follow/Unfollow/Request Error: $e');
    }
  }

  // Profil başlığı (avatar, isim, bio) oluşturan widget.
  Widget _buildProfileHeader(Map<String, dynamic> profileData) {
    final String username = profileData['username'] ?? 'Kullanıcı Adı Yok';
    final String bio = profileData['bio'] ?? 'Biyografi Yok';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade200,
              child: ClipOval(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildImageWidget(profileData), // Use the helper widget
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Username
          Center(
            child: Text(
              username,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Bio
          Center(
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
