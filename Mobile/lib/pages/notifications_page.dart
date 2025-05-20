import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solara/services/api_service.dart';
import 'package:solara/services/user_state.dart';
import 'package:timeago/timeago.dart' as timeago; // For displaying time ago
import 'single_post_page.dart'; // Import SinglePostPage
import 'profile_page.dart'; // Import ProfilePage
import 'messages_page.dart'; // Import MessagesPage

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  // Removed _followRequests list as follow requests are now fetched as notifications
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('[NotificationsPage] initState called.'); // Added print
    // Fetch notifications when the page is initialized
    _fetchNotifications(); // Renamed function
  }

  // Renamed function to reflect fetching only notifications
  Future<void> _fetchNotifications() async {
    print('[NotificationsPage] _fetchNotifications called.'); // Added print
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userState = Provider.of<UserState>(context, listen: false);
      final userId = userState.currentUser?['user_id'];
      print('[NotificationsPage] Current user ID from UserState: $userId');

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in.';
        });
        return;
      }

      print('[NotificationsPage] Attempting to fetch notifications for userId: $userId');
      try {
          // Fetch all notifications, including follow requests, from the single endpoint
          final notifications = await ApiService().fetchNotifications(userId);
          print('[NotificationsPage] Received ${notifications.length} notifications.');
          print('[NotificationsPage] Raw notifications data: $notifications');

          // Filter out notifications where is_deleted is true (backend might already do this, but good to be safe)
          final filteredNotifications = notifications.where((notif) => !(notif['is_deleted'] ?? false)).toList();
          print('[NotificationsPage] Filtered notifications: ${filteredNotifications.length} (deleted: ${notifications.length - filteredNotifications.length})');

           setState(() {
             _notifications = filteredNotifications; // Use filtered notifications
             // Removed setting _followRequests
             _isLoading = false;
           });

      } catch (e_fetch_notifications) {
          print('[NotificationsPage] Error during fetchNotifications: $e_fetch_notifications');
          setState(() {
            _notifications = []; // Clear notifications on error
            _isLoading = false;
            _errorMessage = 'Failed to load notifications: ${e_fetch_notifications.toString()}';
          });
      }


    } catch (e_outer) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: ${e_outer.toString()}';
      });
      print('[NotificationsPage] Outer catch block error: $e_outer');
    }
  }

  Future<void> _markAsRead(int notificationId, int index) async {
    // Find the correct index in the original _notifications list
    final originalIndex = _notifications.indexWhere((notif) => notif['notification_id'] == notificationId);
    if (originalIndex == -1 || _notifications[originalIndex]['is_read']) return; // Not found or already read

    // Optimistically update the UI
    setState(() {
      _notifications[originalIndex]['is_read'] = true;
    });

    try {
      await ApiService().markNotificationAsRead(notificationId);
      print('Notification $notificationId marked as read.');
      // Remove the notification from the list after marking as read
      setState(() {
         _notifications.removeAt(originalIndex);
      });
    } catch (e) {
      print('Error marking notification as read: $e');
      // Optionally show an error message to the user and revert the UI
      // setState(() { _notifications[originalIndex]['is_read'] = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bildirim okundu olarak işaretlenemedi: ${e.toString()}')));
    }
  }

  Future<void> _acceptFollowRequest(int requestId, int index) async {
    print('[NotificationsPage] _acceptFollowRequest called for request ID: $requestId'); // Added log
    try {
      await ApiService().acceptFollowRequest(requestId);
      print('Follow request $requestId accepted.');
      // Remove the request from the list optimistically
      final originalIndex = _notifications.indexWhere((item) => item['request_id'] == requestId && item['type'] == 'follow_request');
       if (originalIndex != -1) {
          final removedItem = _notifications.removeAt(originalIndex);
          setState(() {}); // Update UI

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takip isteği kabul edildi.')));
          // Refetch notifications to get the updated list (the follow request notification should be gone,
          // and a new 'follow' notification might appear depending on backend logic)
          _fetchNotifications();
       } else {
          print('[NotificationsPage] _acceptFollowRequest: Follow request with ID $requestId not found in _notifications list.');
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takip isteği kabul edildi (liste güncelleniyor).')));
           _fetchNotifications(); // Just refetch if optimistic removal index is wrong
       }

    } catch (e) {
      print('Error accepting follow request $requestId: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Takip isteği kabul edilemedi: ${e.toString()}')));
      // Refetch to revert optimistic removal on failure
      _fetchNotifications();
    }
  }

  Future<void> _rejectFollowRequest(int requestId, int index) async {
    print('[NotificationsPage] _rejectFollowRequest called for request ID: $requestId'); // Added log
    try {
      await ApiService().rejectFollowRequest(requestId);
      print('Follow request $requestId rejected.');
      // Remove the request from the list optimistically
      final originalIndex = _notifications.indexWhere((item) => item['request_id'] == requestId && item['type'] == 'follow_request');
       if (originalIndex != -1) {
          final removedItem = _notifications.removeAt(originalIndex);
          setState(() {}); // Update UI

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takip isteği reddedildi.')));
          // Refetch notifications to get the updated list (the follow request notification should be gone)
          _fetchNotifications();
       } else {
          print('[NotificationsPage] _rejectFollowRequest: Follow request with ID $requestId not found in _notifications list.');
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takip isteği reddedildi (liste güncelleniyor).')));
           _fetchNotifications(); // Just refetch if optimistic removal index is wrong
       }

    } catch (e) {
      print('Error rejecting follow request $requestId: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Takip isteği reddedilemedi: ${e.toString()}')));
      // Refetch to revert optimistic removal on failure
      _fetchNotifications();
    }
  }


  // Helper to build notification text based on type
  Widget _buildNotificationText(dynamic item) {
    final actorUsername = item['actor_username'] ?? item['requester_username'] ?? 'Someone';
    final type = item['type'];
    final messagePreview = item['message_preview'];
    // final postThumbnailUrl = item['post_thumbnail_url']; // Not used directly in text

    String text;
    switch (type) {
      case 'like':
        text = '$actorUsername gönderini beğendi.';
        break;
      case 'comment':
        text = '$actorUsername gönderine yorum yaptı: "$messagePreview..."';
        break;
      case 'follow':
        text = '$actorUsername seni takip etmeye başladı.';
        break;
      case 'message':
        text = '$actorUsername sana bir mesaj gönderdi: "$messagePreview..."';
        break;
      case 'follow_request': // Handle follow request text
        text = '$actorUsername seni takip etmek istiyor.';
        break;
      default:
        text = 'Yeni bildirim.';
    }
    return Text(text);
  }

  @override
  Widget build(BuildContext context) {
    // Use only _notifications list as it now includes follow requests
    final allItems = _notifications;
    // Sort by creation date (assuming 'created_at' is available in all notification types)
    allItems.sort((a, b) {
      // Ensure 'created_at' exists and is a string before parsing
      final DateTime dateA = (a != null && a['created_at'] is String) ? DateTime.parse(a['created_at']) : DateTime(0); // Use a default early date if parsing fails
      final DateTime dateB = (b != null && b['created_at'] is String) ? DateTime.parse(b['created_at']) : DateTime(0); // Use a default early date if parsing fails
      return dateB.compareTo(dateA); // Sort in descending order (newest first)
    });


    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : allItems.isEmpty // Check combined list
                  ? const Center(child: Text('No notifications or requests yet.'))
                  : ListView.builder(
                      itemCount: allItems.length,
                      itemBuilder: (context, index) {
                        final item = allItems[index];
                        final type = item['type'];
                        final createdAt = DateTime.parse(item['created_at']); // Assuming ISO 8601 string

                        // Use Dismissible for swipe-to-delete
                        print('[NotificationsPage] Processing item with type: ${item['type']}'); // Add this line
                        return Dismissible(
                          key: Key(item['notification_id']?.toString() ?? item['request_id']?.toString() ?? UniqueKey().toString()), // Unique key for each item
                          direction: DismissDirection.endToStart, // Swipe from right to left
                          background: Container(
                            color: Colors.red, // Red background when swiping
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            print('[NotificationsPage] Dismissible onDismissed triggered for item type: $type'); // Added log
                            // Handle dismissal - always call _deleteNotification for any type of notification
                            if (item['notification_id'] != null) {
                               _deleteNotification(item['notification_id'], index);
                            } else {
                               print('[NotificationsPage] notification_id is null, cannot delete notification.');
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim bilgisi eksik.')));
                            }
                          },
                          child: type == 'follow_request'
                              ? _buildFollowRequestTile(item, index, createdAt)
                              : _buildOtherNotificationTile(item, index, createdAt, type), // Pass type here
                        );
                      },
                    ),
    );
  }

  Widget _buildFollowRequestTile(dynamic item, int index, DateTime createdAt) {
    print('[NotificationsPage] Follow Request Item: $item'); // Keep the print statement
    return ListTile(
      leading: CircleAvatar(
        // Display requester's profile picture
        backgroundImage: item['requester_profile_picture_url'] != null
            ? NetworkImage('${ApiService().baseUrl.replaceAll('/api', '')}${item['requester_profile_picture_url']}')
            : null,
        child: item['requester_profile_picture_url'] == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: _buildNotificationText(item), // Use the helper for text
      subtitle: Text(timeago.format(createdAt)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min, // Use minimum space
        children: [
          ElevatedButton(
            onPressed: item['request_id'] != null
                ? () => _acceptFollowRequest(item['request_id'] as int, index)
                : null, // Disable button if request_id is null
            child: const Text('Kabul Et'),
          ),
          const SizedBox(width: 8), // Space between buttons
          OutlinedButton(
            onPressed: item['request_id'] != null
                ? () => _rejectFollowRequest(item['request_id'] as int, index)
                : null, // Disable button if request_id is null
            child: const Text('Reddet'),
          ),
        ],
      ),
      onTap: () {
        // Optional: Navigate to the requester's profile on tap
        if (item['requester_username'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(username: item['requester_username']),
            ),
          );
        }
      },
    );
  }

  Widget _buildOtherNotificationTile(dynamic item, int index, DateTime createdAt, String type) { // Receive type here
     return ListTile(
        leading: CircleAvatar(
          // Display actor's profile picture if available
          backgroundImage: item['actor_profile_picture_url'] != null
              ? NetworkImage('${ApiService().baseUrl.replaceAll('/api', '')}${item['actor_profile_picture_url']}')
              : null, // Use default avatar if null
          child: item['actor_profile_picture_url'] == null
              ? const Icon(Icons.person) // Default icon
              : null,
        ),
        title: _buildNotificationText(item),
        subtitle: Text(timeago.format(createdAt)), // Display time ago
        trailing: item['is_read'] ?? false
            ? const Icon(Icons.check_circle_outline, color: Colors.green, size: 16)
            : null, // Show checkmark if read
        // Removed tileColor change based on is_read
        onTap: () {
          // Navigate to the relevant page based on notification type
          // Removed _markAsRead call
          if (type == 'like' || type == 'comment') {
            if (item['post_id'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SinglePostPage(postId: item['post_id']),
                ),
              );
            }
          } else if (type == 'follow') {
             if (item['actor_username'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(username: item['actor_username']),
                  ),
                );
              }
          } else if (type == 'message') {
            // For messages, navigate to the chat page with the sender
            // Need to determine the chat partner's ID.
            // Assuming the actor_user_id is the sender in a message notification
            if (item['actor_user_id'] != null && item['recipient_user_id'] != null && item['actor_username'] != null && item['actor_profile_picture_url'] != null) {
                 final userState = Provider.of<UserState>(context, listen: false);
                 final currentUserId = userState.currentUser?['user_id'];

                 if (currentUserId != null) {
                    final chatPartnerId = (item['actor_user_id'] == currentUserId) ? item['recipient_user_id'] : item['actor_user_id'];
                 if (chatPartnerId != null) { // Add null check for chatPartnerId
                     Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MessagesPage(
                              chatPartnerId: chatPartnerId,
                              chatPartnerName: item['actor_username'], // Using username for name
                              chatPartnerUsername: item['actor_username'],
                              chatPartnerAvatarUrl: item['actor_profile_picture_url'],
                            ),
                        ),
                    );
                 } else {
                    print('[NotificationsPage] chatPartnerId is null, cannot navigate to MessagesPage.');
                    // Optionally show a message to the user
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesaj gönderen bilgisi eksik.')));
                 }
                 }
            }
        }
      },
    );
  }


  Future<void> _deleteNotification(int notificationId, int index) async {
    print('[NotificationsPage] _deleteNotification called for ID: $notificationId'); // Added log
    // Find the correct index in the original _notifications list
    final originalIndex = _notifications.indexWhere((notif) => notif['notification_id'] == notificationId);
    if (originalIndex == -1) return; // Not found

    // Remove the notification from the list optimistically
    final removedItem = _notifications.removeAt(originalIndex);
    setState(() {}); // Update UI

    try {
      print('[NotificationsPage] Calling ApiService().deleteNotification for ID: $notificationId');
      final response = await ApiService().deleteNotification(notificationId);
      print('[NotificationsPage] ApiService().deleteNotification response for ID $notificationId: $response');
      print('Notification $notificationId deleted.');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim silindi.')));
    } catch (e) {
      print('[NotificationsPage] Error deleting notification $notificationId: $e');
      // If deletion fails, re-insert the item and show an error
      _notifications.insert(originalIndex, removedItem);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bildirim silinemedi: ${e.toString()}')));
    } catch (error, stackTrace) { // Catch all errors and get stack trace
      print('[NotificationsPage] Caught unexpected error in _deleteNotification: $error');
      print('[NotificationsPage] Stack trace: $stackTrace');
      // Re-insert the item as a fallback
      _notifications.insert(originalIndex, removedItem);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Beklenmeyen bir hata oluştu: ${error.toString()}')));
    }
  }
}
