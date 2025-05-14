import 'package:flutter/material.dart';
import './messages_page.dart'; // Oluşturduğumuz mesajlaşma sayfasını import et
// --- Model for a Chat Summary (Optional but good practice) ---
// Bu model, sohbet listesi sayfasında her bir satırda gösterilecek bilgiyi temsil eder.
class ChatSummary {
  final String partnerName;
  final String partnerUsername;
  final String partnerAvatarUrl;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  // İsteğe bağlı: Okunmamış mesaj sayısı vb. eklenebilir.
  // final int unreadCount;

  ChatSummary({
    required this.partnerName,
    required this.partnerUsername,
    required this.partnerAvatarUrl,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    // this.unreadCount = 0,
  });
}


// --- Sohbet Listesi Sayfası Widget'ı ---
class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  // Listeyi tutacak state değişkeni (Gerçek uygulamada API'den gelir)
  final List<ChatSummary> _chatSummaries = [
    // Static chat summaries for demonstration
    ChatSummary(
      partnerName: "Ahmet Yılmaz",
      partnerUsername: "ahmet_yilmaz",
      partnerAvatarUrl: "assets/images/default_avatar.png", // Replace with actual asset path if available
      lastMessage: "Tamamdır, yarın görüşürüz!",
      lastMessageTimestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    ChatSummary(
      partnerName: "Ayşe Kaya",
      partnerUsername: "ayse_kaya",
      partnerAvatarUrl: "assets/images/default_avatar.png", // Replace with actual asset path if available
      lastMessage: "Proje hakkında konuştuk mu?",
      lastMessageTimestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    ChatSummary(
      partnerName: "Mehmet Demir",
      partnerUsername: "mehmet_demir",
      partnerAvatarUrl: "assets/images/default_avatar.png", // Replace with actual asset path if available
      lastMessage: "Harika bir gün!",
      lastMessageTimestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // No API call needed for static data
  }

  // --- Belirli bir sohbete gitme fonksiyonu ---
  void _navigateToChat(ChatSummary chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessagesPage(
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Sohbetler',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1.0,
        // İsteğe bağlı: Yeni sohbet başlatma butonu vb. eklenebilir
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.add, color: Colors.black),
        //     onPressed: () { /* Yeni sohbet arama/ekleme ekranı */ },
        //   ),
        // ],
      ),
      body: _chatSummaries.isEmpty
          ? const Center(child: Text('Henüz hiç sohbetiniz yok.'))
          : ListView.builder(
              itemCount: _chatSummaries.length,
              itemBuilder: (context, index) {
                final chat = _chatSummaries[index];
                return _buildChatListItem(chat);
              },
            ),
       // Ana uygulamanızda BottomNavigationBar varsa buraya eklemeyin,
       // bu sayfa muhtemelen ana Scaffold'un body'sinde gösterilecek.
    );
  }

  // --- Yardımcı Widget: Tek bir sohbet listesi öğesi ---
  Widget _buildChatListItem(ChatSummary chat) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: AssetImage(chat.partnerAvatarUrl),
         onBackgroundImageError: (exception, stackTrace) {
           // Hata durumunda varsayılan bir ikon veya placeholder gösterilebilir
           print("Avatar yüklenemedi: ${chat.partnerAvatarUrl} - $exception");
         },
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
