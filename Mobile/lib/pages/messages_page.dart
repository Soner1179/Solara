import 'package:flutter/material.dart';
import 'package:solara/models/message_model.dart';
import 'package:solara/services/api_service.dart';
import 'package:solara/services/secure_storage_service.dart'; // For getting current user ID
import 'package:provider/provider.dart'; // For UserState
import 'package:solara/services/user_state.dart'; // For UserState
import 'package:solara/pages/home_page.dart'; // Import HomePage for navigation
import 'package:solara/pages/discover_page.dart'; // Import DiscoverPage for navigation
import 'package:solara/pages/chats_list_page.dart'; // Import ChatsListPage for navigation
import 'package:solara/pages/create_post_page.dart'; // Import CreatePostPage for navigation
import 'package:solara/pages/profile_page.dart'; // Import ProfilePage for navigation
import 'package:solara/pages/notifications_page.dart'; // Import NotificationsPage for navigation
import 'package:solara/constants/api_constants.dart' show defaultAvatar; // Import defaultAvatar

// --- Mesajlar Sayfası Widget'ı ---
class MessagesPage extends StatefulWidget {
  final int chatPartnerId; // Added chatPartnerId
  final String chatPartnerName;
  final String chatPartnerUsername;
  final String chatPartnerAvatarUrl;

  const MessagesPage({
    super.key,
    required this.chatPartnerId, // Added chatPartnerId
    required this.chatPartnerName,
    required this.chatPartnerUsername,
    required this.chatPartnerAvatarUrl,
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  List<Message> _messages = []; // Initialize as empty
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  int? _currentUserId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserIdAndFetchMessages();
    // Scroll to bottom initially - will be handled after messages are loaded
  }

  Future<void> _loadCurrentUserIdAndFetchMessages() async {
    try {
      final userIdString = await SecureStorageService.getUserId();
      if (userIdString == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Kullanıcı kimliği bulunamadı. Lütfen tekrar giriş yapın.";
        });
        return;
      }
      _currentUserId = int.tryParse(userIdString);
      if (_currentUserId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Kullanıcı kimliği geçersiz.";
        });
        return;
      }
      await _fetchMessages();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Kullanıcı bilgileri yüklenirken bir hata oluştu: $e";
      });
    }
  }

  Future<void> _fetchMessages() async {
    if (_currentUserId == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<dynamic> fetchedMessagesData = await _apiService.fetchMessages(_currentUserId!, widget.chatPartnerId);
      final List<Message> fetchedMessages = fetchedMessagesData.map((data) {
        // Assuming your Message.fromJson can handle the structure from API
        // And it correctly determines 'isMe' based on sender_id
        return Message.fromJson(data, _currentUserId!);
      }).toList();

      // Sort messages by timestamp if not already sorted by API
      fetchedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      setState(() {
        _messages = fetchedMessages;
        _isLoading = false;
      });
      _scrollToBottom(animated: false); // Scroll after messages are loaded
    } catch (e) {
      print('Error fetching messages: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Mesajlar yüklenirken bir hata oluştu: $e';
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_currentUserId == null) {
      // Handle error: current user ID not available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mesaj gönderilemedi: Kullanıcı bilgisi eksik.")),
      );
      return;
    }
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      // Optimistically add the message to UI
      final optimisticMessage = Message(
        // id: null, // No ID until backend confirms
        // senderId: _currentUserId!,
        // receiverId: widget.chatPartnerId,
        text: text,
        isMe: true,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(optimisticMessage);
        _messageController.clear();
      });
      _scrollToBottom();

      try {
        final dynamic sentMessageData = await _apiService.sendMessage(
          _currentUserId!,
          widget.chatPartnerId,
          text,
        );
        // Replace optimistic message with confirmed message from backend
        // This assumes the backend returns the full message object
        final confirmedMessage = Message.fromJson(sentMessageData, _currentUserId!);

        setState(() {
          // Find and replace the optimistic message
          // This is a simple way; for more complex scenarios, use unique IDs
          final index = _messages.indexWhere((msg) => msg.timestamp == optimisticMessage.timestamp && msg.text == optimisticMessage.text);
          if (index != -1) {
            _messages[index] = confirmedMessage;
          } else {
            // If not found (shouldn't happen if optimistic add worked), just add it
            _messages.add(confirmedMessage);
            // Re-sort if necessary, though new messages should be at the end
             _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }
        });
      } catch (e) {
        print('Error sending message: $e');
        // Revert optimistic update or show error
        setState(() {
          _messages.remove(optimisticMessage); // Remove the optimistic message
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Mesaj gönderilemedi: ${e.toString()}")),
        );
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final position = _scrollController.position.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(position, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        } else {
          _scrollController.jumpTo(position);
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _selectedIndex = 4; // Set initial index for Messages page

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // Do nothing if tapping the current tab

    setState(() {
      _selectedIndex = index;
    });

    // Navigation logic based on index
    switch (index) {
      case 0: // Ana Sayfa
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1: // Keşfet
         Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DiscoverPage()),
        );
        break;
      case 2: // Oluştur
         Navigator.push( // Use push for Create Post as it's often a modal/overlay
          context,
          MaterialPageRoute(builder: (context) => const CreatePostPage()),
        );
        break;
      case 3: // Bildirimler
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NotificationsPage()),
        );
        break;
      case 4: // Mesajlar (Current page, do nothing)
        break;
      case 5: // Profil (Assuming index 5 for profile based on Home Page structure)
         final userState = Provider.of<UserState>(context, listen: false);
         final currentUsername = userState.currentUser?['username'];
         if (currentUsername != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage(username: currentUsername)),
            );
         } else {
            // Handle case where user is not logged in
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Profilinizi görmek için giriş yapmalısınız.')),
             );
         }
        break;
    }
  }

  // Helper for building nav icons (Copied from home_page.dart)
  Widget _buildNavIcon(String path, {double size = 24}) {
    return Image.asset(
      path, width: size, height: size,
      errorBuilder: (context, error, stackTrace) {
        print('Nav icon load error ($path): $error');
        return Icon(Icons.broken_image_outlined, size: size, color: Colors.grey.shade600);
      },
    );
  }

  // --- Asset Paths (Copied from home_page.dart) ---
  static const String _iconPath = 'assets/images/';
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
  static const String sidebarContestIcon = '${_iconPath}competition.png';
  static const String moonIcon = '${_iconPath}moon.png';
  static const String likeIcon = '${_iconPath}like.png';
  static const String likeRedIcon = '${_iconPath}like(red).png';
  static const String commentIcon = '${_iconPath}comment.png';
  static const String bookmarkBlackIcon = '${_iconPath}bookmark(black).png';
  static const String bookmarkTappedIcon = '${_iconPath}bookmark(tapped).png';
  static const String postPlaceholderIcon = '${_iconPath}post_placeholder.png';
  static const String _notFoundImage = 'assets/images/not-found.png';
  // --- End Asset Paths ---


  @override
  Widget build(BuildContext context) {
    //!-- TEMAYI VE RENK ŞEMASINI AL --!//
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Tema parlaklığını kontrol et (açık mı koyu mu)
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      //!-- Scaffold arkaplanı TEMA'dan gelmeli --!//
      // backgroundColor: colorScheme.background, // ThemeData'da tanımlı olmalı

      appBar: AppBar(
        //!-- AppBar stilinin TEMA'dan (AppBarTheme) gelmesi en iyisidir --!//
        // backgroundColor: colorScheme.surface, // Gerekirse üzerine yaz
        // foregroundColor: colorScheme.onSurface, // Gerekirse üzerine yaz
        elevation: 0.5,
        scrolledUnderElevation: 1.0,
        titleSpacing: 0,
        title: Row(
          children: [
            Builder( // Use Builder to get context for ApiService if needed, or ensure _apiService is accessible
              builder: (context) {
                ImageProvider backgroundImageProvider;
                String imageUrl = widget.chatPartnerAvatarUrl;

                if (imageUrl.startsWith('/uploads/')) {
                  final serverBase = _apiService.baseUrl.replaceAll('/api', '');
                  backgroundImageProvider = NetworkImage('$serverBase$imageUrl');
                } else {
                  backgroundImageProvider = AssetImage(imageUrl);
                }
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.secondaryContainer,
                  backgroundImage: backgroundImageProvider,
                );
              }
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatPartnerName,
                  //!-- AppBar başlık stili TEMA'dan gelmeli (AppBarTheme.titleTextStyle) --!//
                  // Style temadan alınırsa, burada tekrar belirtmeye gerek yok.
                  // style: TextStyle( fontWeight: FontWeight.bold, fontSize: 16,),
                ),
                Text(
                  widget.chatPartnerUsername,
                  //!-- İkincil metin rengi TEMA'dan (daha soluk) --!//
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7), // Yüzey rengi üzerine soluk
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text("Henüz mesaj yok.", style: TextStyle(color: theme.hintColor)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      //!-- Mesaj balonu widget'ına renkleri ve durumu ilet --!//
                      return _buildMessageBubble(message, theme, colorScheme, isDarkMode);
                    },
                  ),
          ),
          //!-- Giriş alanı widget'ına renkleri ilet --!//
          _buildMessageInputArea(theme, colorScheme),
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
          BottomNavigationBarItem( icon: _buildNavIcon(searchIcon), activeIcon: _buildNavIcon(searchIcon), label: 'Keşfet',),
          BottomNavigationBarItem( icon: _buildNavIcon(postIcon), activeIcon: _buildNavIcon(postBlackIcon), label: 'Oluştur',),
          BottomNavigationBarItem( icon: _buildNavIcon(notificationIcon), activeIcon: _buildNavIcon(notificationBlackIcon), label: 'Bildirimler',),
          BottomNavigationBarItem( icon: _buildNavIcon(sendIcon), activeIcon: _buildNavIcon(sendBlackIcon), label: 'Mesajlar',),
          // Add Profile icon if needed, adjust index accordingly
          // BottomNavigationBarItem( icon: Icon(Icons.person), label: 'Profil',),
        ],
      ),
    );
  }

  // --- Yardımcı Widget: Tek Bir Mesaj Balonu Oluştur ---
  Widget _buildMessageBubble(Message message, ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    final bool isMe = message.isMe;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleAlignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    //!-- Mesaj Balonu Renkleri (TEMA'dan) --!//
    // Gönderen (isMe=true): Genellikle primary renk kullanılır.
    // Alıcı (isMe=false): Açık temada gri tonu, koyu temada ana arkaplandan hafif farklı bir ton iyidir.
    //                    `surfaceVariant` veya `secondaryContainer` genellikle iyi çalışır.
    //                    `ThemeData.colorScheme` içinde bu renklerin Koyu mod için de tanımlı olduğundan emin olun!
    final bubbleColor = isMe
        ? colorScheme.primary
        : (isDarkMode ? colorScheme.surfaceVariant : Colors.grey.shade200); // Koyu tema için surfaceVariant, açık için gri
        // VEYA: : colorScheme.secondaryContainer; // Her iki tema için secondaryContainer da deneyebilirsiniz.

    //!-- Metin Renkleri (TEMA'dan - Balon rengine göre okunabilir olmalı) --!//
    final textColor = isMe
        ? colorScheme.onPrimary // primary renk üzerine okunabilir renk
        : colorScheme.onSurfaceVariant; // surfaceVariant (veya seçtiğiniz diğer renk) üzerine okunabilir renk
        // VEYA isMe false ise: colorScheme.onSecondaryContainer;

    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
       child: Row(
           mainAxisAlignment: bubbleAlignment,
           children: [
               Container(
                   constraints: BoxConstraints(
                       maxWidth: MediaQuery.of(context).size.width * 0.75,
                   ),
                   padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                   decoration: BoxDecoration(
                       color: bubbleColor, //!-- Tema rengi uygulandı --!//
                       borderRadius: BorderRadius.only(
                           topLeft: const Radius.circular(20.0),
                           topRight: const Radius.circular(20.0),
                           bottomLeft: Radius.circular(isMe ? 20.0 : 4),
                           bottomRight: Radius.circular(isMe ? 4 : 20.0),
                       ),
                   ),
                   child: Column(
                       crossAxisAlignment: alignment,
                       mainAxisSize: MainAxisSize.min,
                       children: [
                           Text(
                               message.text,
                               style: TextStyle(color: textColor, fontSize: 15), //!-- Tema rengi uygulandı --!//
                           ),
                           const SizedBox(height: 4),
                           Text(
                               '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                               style: TextStyle(
                                   //!-- Saat metni rengi (ana metinden daha soluk) --!//
                                   color: textColor.withOpacity(0.7),
                                   fontSize: 11,
                               ),
                           ),
                       ],
                   ),
               ),
           ],
       ),
    );
  }

  // --- Yardımcı Widget: Alt Giriş Alanını Oluştur ---
  Widget _buildMessageInputArea(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      //!-- Giriş alanı arka planı TEMA'dan --!//
      color: colorScheme.surface, // Veya theme.bottomAppBarColor belki?
      padding: EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        top: 8.0,
        //!-- Klavyenin altındaki boşluk için SafeArea'dan gelen padding'i ekle --!//
        bottom: MediaQuery.of(context).padding.bottom + 8.0,
      ),
      // decoration: BoxDecoration( // Artık color kullandığımız için decoration yerine onu kullanıyoruz
      //   color: colorScheme.surface,
      //   border: Border(
      //     top: BorderSide(color: theme.dividerColor, width: 0.5)
      //   ),
      // ),
      // SafeArea'yı Container'ın padding'i ile yönetiyoruz, ayrı widget'a gerek yok
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                 //!-- TextField arka planı TEMA'dan (InputDecorationTheme veya surfaceVariant) --!//
                 // inputDecorationTheme'da fillColor tanımlıysa onu kullanmak en doğrusu
                 color: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant.withOpacity(0.6),
                 borderRadius: BorderRadius.circular(20.0),
              ),
              child: SingleChildScrollView(
                child: TextField(
                  controller: _messageController,
                   //!-- TextField metin stili TEMA'dan --!//
                  style: TextStyle(color: colorScheme.onSurfaceVariant), // surfaceVariant üzerine okunabilir renk
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                     //!-- İpucu metni rengi TEMA'dan (soluk) --!//
                    hintStyle: TextStyle(color: (theme.inputDecorationTheme.hintStyle?.color ?? colorScheme.onSurfaceVariant).withOpacity(0.6)),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                ),
              ),
            ),
          ),
          IconButton(
            //!-- Gönder butonu rengi TEMA'dan --!//
            icon: Icon(Icons.send, color: colorScheme.primary),
            iconSize: 26,
            padding: const EdgeInsets.all(10),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
