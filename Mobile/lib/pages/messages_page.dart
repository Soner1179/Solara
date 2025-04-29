import 'package:flutter/material.dart';
import 'package:solara/models/message_model.dart'; // Model importu

// --- Model for a Message ---
// (Bir önceki adımdaki gibi, ya ayrı dosyada ya da burada tanımlı olmalı)
// class Message { ... }


// --- Mesajlar Sayfası Widget'ı ---
class MessagesPage extends StatefulWidget {
  final String chatPartnerName;
  final String chatPartnerUsername;
  final String chatPartnerAvatarUrl;

  const MessagesPage({
    super.key,
    required this.chatPartnerName,
    required this.chatPartnerUsername,
    required this.chatPartnerAvatarUrl,
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [
    // Static messages for demonstration
    Message(text: "Merhaba!", isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
    Message(text: "Selam, nasılsın?", isMe: true, timestamp: DateTime.now().subtract(const Duration(minutes: 4))),
    Message(text: "İyiyim, sen nasılsın?", isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 3))),
    Message(text: "Ben de iyiyim, teşekkürler.", isMe: true, timestamp: DateTime.now().subtract(const Duration(minutes: 2))),
    Message(text: "Ne yapıyorsun?", isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 1))),
    Message(text: "Flutter ile mesajlaşma ekranı yapıyorum.", isMe: true, timestamp: DateTime.now()),
  ];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll to bottom initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final newMessage = Message(
        text: text,
        isMe: true, // Assume sent messages are from the current user
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(newMessage);
        _messageController.clear();
      });
      _scrollToBottom();
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
            CircleAvatar(
              radius: 18,
              //!-- Avatar arkaplanı TEMA'dan --!//
              backgroundColor: colorScheme.secondaryContainer,
              backgroundImage: AssetImage(widget.chatPartnerAvatarUrl),
              onBackgroundImageError: (exception, stackTrace) { /*...*/ },
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
