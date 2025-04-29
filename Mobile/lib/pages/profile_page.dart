// lib/pages/profile_page.dart
import 'dart:convert'; // JSON dönüşümleri için gerekli.
import 'package:flutter/material.dart'; // Flutter Material Design widget'ları.
// import 'package:http/http.dart' as http; // HTTP istekleri yapmak için. // Removed http import
import 'package:solara/services/api_service.dart'; // ApiService importu <--- EKLENDİ
import 'package:solara/pages/single_post_page.dart'; // SinglePostPage importu <--- EKLENDİ
import 'package:solara/constants/api_constants.dart'; // ApiConstants importu <--- EKLENDİ

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
            child: CircleAvatar(
              radius: 42, // İç çember yarıçapı (asıl avatar).
              // Display static profile picture from uploads folder as requested
              backgroundImage: NetworkImage('$baseUrl/uploads/pp.png') as ImageProvider<Object>, // Use NetworkImage with static path
              backgroundColor: Colors.grey.shade300, // Resim yüklenemezse görünen renk.
              onBackgroundImageError: (exception, stackTrace) {
                 print('Error loading static profile image: $exception');
                 // Optionally set a state to show a broken image icon or fallback
              },
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
     // Izgara görünümü.
    return GridView.builder(
      padding: const EdgeInsets.all(1.0), // Izgara kenarlarında hafif boşluk.
      // Izgara düzeni: Sabit 3 sütunlu, öğeler arası boşluklu.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 3, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5,),
      itemCount: posts.length, // Izgara öğe sayısı.
      shrinkWrap: true, // İçeriğe göre boyutlanmasını sağlar (NestedScrollView içinde gerekli).
      physics: const NeverScrollableScrollPhysics(), // Kendi kaydırmasını engeller (NestedScrollView kaydıracak).
      // Her bir ızgara öğesini oluşturur.
      itemBuilder: (context, index) {
        final post = posts[index];
        // Assuming post object has 'image_url'
        final String imageUrl = post['image_url'] ?? 'assets/images/post_placeholder.png'; // Use placeholder if no image

        Widget imageWidget;
        if (imageUrl.startsWith('assets/')) {
          // Load from assets
          imageWidget = Image.asset(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade600)),
          );
        } else if (imageUrl.startsWith('/uploads/')) {
          // Load from network with base URL
          final String fullImageUrl = '$baseUrl$imageUrl';
          imageWidget = Image.network(
            fullImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade600)),
          );
        } else {
          // Assume it's a full network URL
          imageWidget = Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade600)),
          );
        }


        return GestureDetector(
          onTap: () {
            // Navigate to single post view
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SinglePostPage(postId: post['post_id']), // Assuming SinglePostPage exists
              ),
            );
          },
          child: Container(
            color: Colors.grey[300], // Placeholder background
            child: imageWidget, // Use the determined image widget
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
