// lib/models/message_model.dart

// İleride gerekebilecek API yanıtlarına göre daha detaylı hale getirilebilir.
// Örneğin: String id, String senderUsername, MessageStatus status vb.

class Message {
  final String text;
  final bool isMe; // Mesaj mevcut kullanıcıdan mı geldi?
  final DateTime timestamp; // Sıralama veya gösterme için zaman damgası

  Message({
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  // API'den gelen JSON verisini parse etmek için
  factory Message.fromJson(Map<String, dynamic> json, int currentUserId) { // Added currentUserId parameter
    return Message(
      text: json['message_text'] ?? '', // Use 'message_text' from backend
      isMe: json['sender_user_id'] == currentUserId, // Compare sender_user_id with currentUserId
      timestamp: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ?? DateTime.now(), // Use 'created_at' from backend
      // id: json['message_id'], // Assuming backend returns message_id
      // senderUsername: json['sender_username'], // Assuming backend joins to get sender username
    );
  }
}

// Opsiyonel: Mesaj durumları için enum
// enum MessageStatus { sending, sent, delivered, read, failed }
