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

  // Placeholder veriler - TODO: Gerçek gönderileri/verileri API'den çek.
  // Kullanıcının gönderilerini tutan liste.
  List<Map<String, dynamic>> _userPosts = []; // Removed final and changed type
  // Etiketlenen gönderileri tutan geçici liste.
  final List<String> _taggedPosts = List.generate(3, (i) => "Tagged ${i+1}"); // Keep as is for now
  // TODO: Gerçek giriş yapmış kullanıcı kontrolü ile değiştirin.
  // Geçici olarak giriş yapmış kullanıcı adı.
  final String _loggedInUsername = "soner1179";

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
  Future<void> _fetchUserPosts(int userId) async { // Changed parameter to userId
    print("Kullanıcı için gönderiler çekiliyor: $userId");
    final apiService = ApiService();
    final String endpoint = 'users/$userId/posts'; // Use the endpoint with user_id

    try {
      final List<dynamic> data = await apiService.get(endpoint);

      if (!mounted) return;

      setState(() {
        _userPosts = List<Map<String, dynamic>>.from(data); // Update _userPosts with fetched data
      });

    } catch (e) {
      if (!mounted) return;
      print('Kullanıcı gönderileri çekme hatası: $e');
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
    // This check might need to be more robust in a real app (e.g., comparing user IDs)
    final bool isCurrentUserProfile = _profileData?['username'] == _loggedInUsername; // Use fetched username



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
                child: FadeInImage.assetNetwork(
                  placeholder: defaultAvatar, // Local asset placeholder
                  image: '${ApiEndpoints.baseUrl}/uploads/pp.png', // Network image URL
                  fit: BoxFit.cover,
                  imageErrorBuilder: (context, error, stackTrace) {
                    print('Error loading profile image: $error');
                    return Image.asset( // Fallback to default avatar on error
                      defaultAvatar,
                      fit: BoxFit.cover,
                    );
                  },
                  placeholderErrorBuilder: (context, error, stackTrace) {
                     print('Error loading profile placeholder: $error');
                     return Image.asset( // Fallback if placeholder fails
                       defaultAvatar,
                       fit: BoxFit.cover,
                     );
                  },
                ),
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
            _buildStatItem(solarPoints.toString(), 'Solar Puanı'),
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
     // Backend henüz 'is_following' durumu döndürmüyor. Uygulanırsa mantık eklenmeli.
     bool isFollowing = false; // Placeholder - Takip durumu (şimdilik hep false).

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
                    onPressed: () { print("Takip Et/Bırak Tıklandı (TODO)"); }, // Tıklanma eylemi (TODO).
                     style: ElevatedButton.styleFrom( // Buton stili.
                       // Takip ediliyorsa beyaz arka plan, edilmiyorsa tema rengi.
                       backgroundColor: isFollowing ? Colors.white : Theme.of(context).primaryColor,
                       // Takip ediliyorsa siyah metin, edilmiyorsa beyaz metin.
                       foregroundColor: isFollowing ? Colors.black : Colors.white,
                       // Takip ediliyorsa kenarlık ekle.
                       side: isFollowing ? BorderSide(color: Colors.grey.shade400) : null,
                       padding: const EdgeInsets.symmetric(vertical: 10), // İç dikey boşluk.
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Köşeleri yuvarlat.
                       elevation: isFollowing ? 0 : 2, // Takip edilmiyorsa hafif gölge.
                    ),
                    // Takip durumuna göre buton metni.
                    child: Text(isFollowing ? 'Takip Ediliyor' : 'Takip Et'),
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
                     GestureDetector( onTap: () { /* TODO: Navigate to profile */ }, child: CircleAvatar( radius: 18, backgroundColor: colorScheme.secondaryContainer, backgroundImage: NetworkImage('${ApiEndpoints.baseUrl}/uploads/pp.png'), onBackgroundImageError: (e,s) => print("Post avatar network error (${ApiEndpoints.baseUrl}/uploads/pp.png): $e"), ), ),
                     const SizedBox(width: 10),
                     Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ GestureDetector( onTap: () { /* TODO: Navigate to profile */ }, child: Text( postUsername, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis, ), ), if (postLocation != null && postLocation.isNotEmpty) Text( postLocation, style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor), maxLines: 1, overflow: TextOverflow.ellipsis, ), ], ), ),
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
                        placeholder: 'assets/images/post_placeholder.png', // Local asset placeholder
                        // Construct full image URL if it's a relative path from backend uploads
                        image: (postImageUrl != null && postImageUrl.startsWith('/uploads/'))
                            ? '${ApiEndpoints.baseUrl.replaceAll('/api', '')}$postImageUrl' // Prepend backend server base URL
                            : postImageUrl ?? '', // Use as is (should be full URL or null)
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
                     IconButton( icon: Image.asset( isBookmarked ? 'assets/images/bookmark(tapped).png' : 'assets/images/bookmark(black).png', width: 26, height: 26, color: bookmarkColor, ), tooltip: 'Kaydet', onPressed: () => _toggleBookmark(index), ), // Calls _toggleBookmark
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
}
