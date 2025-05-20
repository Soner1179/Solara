import 'package:flutter/material.dart';
import 'package:solara/services/api_service.dart';
import 'package:solara/services/secure_storage_service.dart';
import './messages_page.dart';
// Import a new page for starting new chats
import './new_chat_search_page.dart';

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
      setState(() {
        _chatSummaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching chat summaries: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sohbetler yüklenirken bir hata oluştu: $e';
      });
    }
  }

  void _navigateToChat(ChatSummary chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessagesPage(
          chatPartnerId: chat.partnerId, // Pass the partnerId
          chatPartnerName: chat.partnerName,
          chatPartnerUsername: chat.partnerUsername,
          chatPartnerAvatarUrl: chat.partnerAvatarUrl,
        ),
      ),
    );
  }

  // --- UI Oluşturma ---
  @override
  Widget build(BuildContext context) {
    // Removed Scaffold and AppBar to be embedded in HomePage's Scaffold
    return _isLoading
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
                    onRefresh: _fetchChats, // Pull to refresh
                    child: ListView.builder(
                      itemCount: _chatSummaries.length,
                      itemBuilder: (context, index) {
                        final chat = _chatSummaries[index];
                        return _buildChatListItem(chat);
                      },
                    ),
                  );
  }

  // --- Yardımcı Widget: Tek bir sohbet listesi öğesi ---
  Widget _buildChatListItem(ChatSummary chat) {
    ImageProvider backgroundImageProvider;
    String imageUrl = chat.partnerAvatarUrl;

    if (imageUrl.startsWith('/uploads/')) {
      // Construct the full network URL
      final serverBase = _apiService.baseUrl.replaceAll('/api', '');
      backgroundImageProvider = NetworkImage('$serverBase$imageUrl');
    } else {
      // Assume it's a local asset path (like the default avatar)
      backgroundImageProvider = AssetImage(imageUrl);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey.shade300, // Fallback color
        backgroundImage: backgroundImageProvider,
        // You can add a child for a placeholder/error icon if NetworkImage fails,
        // but CircleAvatar will show backgroundColor by default on error.
        // child: someCondition ? Icon(Icons.error) : null,
      ),
      title: Text(
        chat.partnerName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis, // Uzun mesajları ... ile kısalt
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Text(
        // Zamanı daha okunabilir formatta göster (ör: 10:30, Dün, 25.10.2023)
        _formatTimestamp(chat.lastMessageTimestamp),
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
      onTap: () => _navigateToChat(chat), // Tıklanınca ilgili sohbete git
    );
  }

  // --- Yardımcı Fonksiyon: Zaman damgasını formatlama ---
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0 && now.day == timestamp.day) {
      // Bugün ise sadece saati göster (ör: 15:30)
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != timestamp.day)) {
      // Dün ise "Dün" yaz
      return 'Dün';
    } else if (difference.inDays < 7) {
      // Bu hafta içinde ise gün adını göster (ör: Pzt) - İsteğe bağlı, daha detaylı yapılabilir
       switch(timestamp.weekday) {
         case DateTime.monday: return 'Pzt';
         case DateTime.tuesday: return 'Sal';
         case DateTime.wednesday: return 'Çar';
         case DateTime.thursday: return 'Per';
         case DateTime.friday: return 'Cum';
         case DateTime.saturday: return 'Cmt';
         case DateTime.sunday: return 'Paz';
         default: return ''; // Hata durumu
       }
    } else {
      // Daha eski ise tarihi göster (ör: 25.10.2023)
      return '${timestamp.day}.${timestamp.month}.${timestamp.year}';
    }
  }
}
