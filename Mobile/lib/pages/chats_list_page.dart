import 'package:flutter/material.dart';
import 'package:solara/services/api_service.dart';
import 'package:solara/services/secure_storage_service.dart';
import './messages_page.dart';
import './new_chat_search_page.dart';
import 'package:solara/pages/home_page.dart'; // HomePage'e navigasyon için
import 'package:solara/pages/create_post_page.dart'; // CreatePostPage'e navigasyon için
import 'package:solara/pages/discover_page.dart'; // DiscoverPage'e navigasyon için


// --- Asset Paths (home_page.dart'tan kopyalandı ve güncellendi) ---
const String _iconPath = 'assets/images/';
const String homeIcon = '${_iconPath}home.png';
const String homeBlackIcon = '${_iconPath}home(black).png';
const String homeWhiteIcon = '${_iconPath}home(white).png'; // Eklendi
const String searchIcon = '${_iconPath}search.png';
const String searchBIcon = 'assets/images/searchBIcon.png'; // Bu özel bir durum gibi, normalde search(black) olurdu
const String searchWhiteIcon = '${_iconPath}search(white).png'; // Eklendi
const String postIcon = '${_iconPath}post.png';
const String postBlackIcon = '${_iconPath}post(black).png';
const String postWhiteIcon = '${_iconPath}post(white).png'; // Eklendi
const String notificationIcon = '${_iconPath}notification.png';
const String notificationBlackIcon = '${_iconPath}notification(black).png';
const String notificationWhiteIcon = '${_iconPath}notification(white).png'; // Eklendi
const String sendIcon = '${_iconPath}send.png';
const String sendBlackIcon = '${_iconPath}send(black).png';
const String sendWhiteIcon = '${_iconPath}send(white).png'; // Eklendi
// --- End Asset Paths ---


// --- Model for a Chat Summary ---
class ChatSummary {
  final int partnerId;
  final String partnerName;
  final String partnerUsername;
  final String partnerAvatarUrl;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  // final bool isRead; // Optional: if backend provides this

  ChatSummary({
    required this.partnerId,
    required this.partnerName,
    required this.partnerUsername,
    required this.partnerAvatarUrl,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    // required this.isRead,
  });

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    String? pFullName = json['partner_name'] as String?; // This is users.full_name
    String? pUsername = json['partner_username'] as String?;

    String displayName;
    if (pFullName != null && pFullName.isNotEmpty) {
      displayName = pFullName;
    } else if (pUsername != null && pUsername.isNotEmpty) {
      displayName = pUsername; // Fallback to username if full_name is not available
    } else {
      displayName = 'Bilinmeyen Kullanıcı'; // Ultimate fallback
    }

    return ChatSummary(
      partnerId: json['partner_user_id'] as int? ?? 0,
      partnerName: displayName, // Use the resolved display name
      partnerUsername: pUsername ?? 'unknown_user', // Store the actual username separately
      partnerAvatarUrl: json['partner_avatar_url'] as String? ?? "assets/images/default_avatar.png",
      lastMessage: json['message_text'] as String? ?? '',
      lastMessageTimestamp: DateTime.tryParse(json['last_message_timestamp'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

// --- Sohbet Listesi Sayfası Widget'ı ---
class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  List<ChatSummary> _chatSummaries = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentUserId;
  final ApiService _apiService = ApiService();

  // --- Bottom Navigation Bar için Gerekli Kısım (home_page.dart'tan uyarlandı) ---
  int _selectedIndex = 4; // "Mesajlar" sekmesi aktif

  Widget _buildNavIcon(String path, {double size = 24}) {
    return Image.asset(
      path,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) {
        print('Nav icon load error ($path): $error');
        return Icon(Icons.broken_image_outlined, size: size, color: Colors.grey.shade600);
      },
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // Zaten bu sayfadayız

    switch (index) {
      case 0: // Ana Sayfa
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 0)),
          (Route<dynamic> route) => false,
        );
        break;
      case 1: // Keşfet
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 1)),
          (Route<dynamic> route) => false,
        );
        break;
      case 3: // Bildirimler
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 3)),
          (Route<dynamic> route) => false,
        );
        break;
      case 2: // Oluştur
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CreatePostPage()),
        );
        break;
      case 4: // Mesajlar - Zaten buradayız
        break;
    }
  }
  // --- End Bottom Navigation Bar için Gerekli Kısım ---

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndFetchChats();
  }

  Future<void> _loadCurrentUserAndFetchChats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userIdString = await SecureStorageService.getUserId();
      if (userIdString == null) {
        throw Exception("Kullanıcı kimliği bulunamadı. Lütfen tekrar giriş yapın.");
      }
      _currentUserId = int.tryParse(userIdString);
      if (_currentUserId == null) {
        throw Exception("Kullanıcı kimliği geçersiz.");
      }
      await _fetchChats();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchChats() async {
    if (_currentUserId == null) return;
    try {
      final List<dynamic> fetchedData = await _apiService.fetchChatSummaries(_currentUserId!);
      final List<ChatSummary> summaries = fetchedData
          .map((data) => ChatSummary.fromJson(data as Map<String, dynamic>))
          .toList();
      if(mounted){
        setState(() {
          _chatSummaries = summaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching chat summaries: $e');
      if(mounted){
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sohbetler yüklenirken bir hata oluştu: $e';
        });
      }
    }
  }

  void _navigateToChat(ChatSummary chat) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessagesPage(
          chatPartnerId: chat.partnerId,
          chatPartnerName: chat.partnerName,
          chatPartnerUsername: chat.partnerUsername,
          chatPartnerAvatarUrl: chat.partnerAvatarUrl,
        ),
      ),
    );
    // Mesajlar sayfasından dönüldüğünde listeyi yenilemek gerekebilir
    if (result == true || result == null) { // result null ise de yenileme yapabiliriz (geri tuşu ile çıkış)
      _fetchChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Theme'i burada alalım
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Sohbetler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Yeni Sohbet Başlat',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewChatSearchPage()),
              );
              if (result == true) {
                _fetchChats();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Hata: $_errorMessage', textAlign: TextAlign.center),
                  ),
                )
              : _chatSummaries.isEmpty
                  ? Center(
                      child: Text(
                      'Henüz hiç sohbetiniz yok.\nSağ üstteki + butonuna dokunarak yeni bir sohbet başlatın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ))
                  : RefreshIndicator(
                      onRefresh: _fetchChats,
                      child: ListView.builder(
                        itemCount: _chatSummaries.length,
                        itemBuilder: (context, index) {
                          final chat = _chatSummaries[index];
                          return _buildChatListItem(chat);
                        },
                      ),
                    ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: _buildNavIcon(theme.brightness == Brightness.dark ? homeWhiteIcon : homeIcon),
            activeIcon: _buildNavIcon(theme.brightness == Brightness.dark ? homeWhiteIcon : homeBlackIcon),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(theme.brightness == Brightness.dark ? searchWhiteIcon : searchIcon),
            activeIcon: _buildNavIcon(theme.brightness == Brightness.dark ? searchWhiteIcon : searchBIcon), // searchBIcon light mode için kalabilir
            label: 'Keşfet',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(theme.brightness == Brightness.dark ? postWhiteIcon : postIcon),
            activeIcon: _buildNavIcon(theme.brightness == Brightness.dark ? postWhiteIcon : postBlackIcon),
            label: 'Oluştur',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(theme.brightness == Brightness.dark ? notificationWhiteIcon : notificationIcon),
            activeIcon: _buildNavIcon(theme.brightness == Brightness.dark ? notificationWhiteIcon : notificationBlackIcon),
            label: 'Bildirimler',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(theme.brightness == Brightness.dark ? sendWhiteIcon : sendIcon),
            activeIcon: _buildNavIcon(theme.brightness == Brightness.dark ? sendWhiteIcon : sendBlackIcon),
            label: 'Mesajlar',
          ),
        ],
      ),
    );
  }

  Widget _buildChatListItem(ChatSummary chat) {
    ImageProvider backgroundImageProvider;
    String imageUrl = chat.partnerAvatarUrl;

    // _apiService.baseUrl null kontrolü eklendi
    final apiBaseUrl = _apiService.baseUrl; 
    if (apiBaseUrl != null && imageUrl.startsWith('/uploads/')) {
      final serverBase = apiBaseUrl.replaceAll('/api', '');
      backgroundImageProvider = NetworkImage('$serverBase$imageUrl');
    } else if (imageUrl.startsWith('http')) {
      backgroundImageProvider = NetworkImage(imageUrl);
    }
    else {
      backgroundImageProvider = AssetImage(imageUrl.isNotEmpty ? imageUrl : "assets/images/default_avatar.png");
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: backgroundImageProvider,
         onBackgroundImageError: (_, __) { // Hata durumunda fallback
          if (mounted) {
            setState(() {
              // Bu, CircleAvatar'ın kendisini yeniden çizmesini tetiklemez,
              // ancak bir sonraki build'de farklı bir image provider kullanılabilir.
              // Daha iyi bir çözüm, ChatSummary modelinde bir error flag tutmak olabilir.
              print("Error loading image: $imageUrl. Falling back to default.");
              // Burada doğrudan default avatarı set etmek yerine,
              // backgroundImageProvider'ı default asset'e ayarlamak daha doğru olurdu
              // ancak bu _buildChatListItem çağrıldığında yapılmalı.
              // Şimdilik, CircleAvatar'ın backgroundColor'ı fallback olacak.
            });
          }
        },
      ),
      title: Text(
        chat.partnerName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Text(
        _formatTimestamp(chat.lastMessageTimestamp),
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
      onTap: () => _navigateToChat(chat),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0 && now.day == timestamp.day) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != timestamp.day)) {
      return 'Dün';
    } else if (difference.inDays < 7) {
       switch(timestamp.weekday) {
         case DateTime.monday: return 'Pzt';
         case DateTime.tuesday: return 'Sal';
         case DateTime.wednesday: return 'Çar';
         case DateTime.thursday: return 'Per';
         case DateTime.friday: return 'Cum';
         case DateTime.saturday: return 'Cmt';
         case DateTime.sunday: return 'Paz';
         default: return '';
       }
    } else {
      return '${timestamp.day}.${timestamp.month}.${timestamp.year}';
    }
  }
}
