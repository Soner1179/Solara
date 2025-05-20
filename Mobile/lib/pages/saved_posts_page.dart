import 'dart:math'; // Simülasyon için (kaldırılabilir)
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // RichText için
import 'package:solara/constants/api_constants.dart'; // Import ApiConstants <--- EKLENDİ
import 'package:solara/pages/profile_page.dart'; // Profil sayfasına gitmek için
import 'package:solara/services/api_service.dart'; // ApiService importu
import 'package:solara/services/secure_storage_service.dart'; // Import SecureStorageService
import 'package:solara/widgets/post_card.dart'; // Import the new PostCard widget

// Sabitleri ortak bir dosyadan almak en iyisidir.
// import 'package:solara/constants/app_assets.dart';


class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  List<Map<String, dynamic>> _savedPosts = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentUserId; // Make nullable and not final

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndFetchPosts();
  }

  Future<void> _loadCurrentUserAndFetchPosts() async {
    final userIdString = await SecureStorageService.getUserId();
    if (userIdString != null) {
      setState(() {
        _currentUserId = int.tryParse(userIdString);
      });
      if (_currentUserId != null) {
        _fetchSavedPosts();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Kullanıcı ID'si alınamadı.";
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Lütfen giriş yapın."; // User not logged in
      });
    }
  }

  Future<void> _fetchSavedPosts() async {
    if (!mounted || _currentUserId == null) return; // Check if user ID is available
    setState(() {
      _isLoading = true;
      _errorMessage = null; 
      _savedPosts = []; 
    });

    try {
      final apiService = ApiService();
      final List<dynamic> data = await apiService.fetchSavedPosts(_currentUserId!); // Use non-null assertion

      if (!mounted) return;

      setState(() {
        // Map the fetched data to the desired format (similar to home_page.dart)
        _savedPosts = List<Map<String, dynamic>>.from(data.map((post) => {
           'id': post['post_id'].toString(), // Use post_id from backend
           'user_id': post['user_id'], // This is the original post's user_id
           'username': post['post_author_username'] ?? '', // Use post_author_username from backend
           'raw_avatar_for_debug': post['post_author_avatar'], // DEBUG: Store raw avatar URL
           'avatarUrl': (post['post_author_avatar'] != null && post['post_author_avatar'].isNotEmpty)
               ? (post['post_author_avatar'].startsWith('/uploads/')
                  ? '${ApiEndpoints.baseUrl}${post['post_author_avatar']}'
                  : post['post_author_avatar'])
               : null, // Let PostCard handle the default avatar if null/empty
           'imageUrl': (post['image_url'] != null && post['image_url'].isNotEmpty)
               ? (post['image_url'].startsWith('/uploads/')
                  ? '${ApiEndpoints.baseUrl}${post['image_url']}'
                  : post['image_url'])
               : null, // If no image_url from backend, set to null
           'caption': post['content_text'] ?? '', // Use content_text from backend
           'likeCount': post['likes_count'] ?? 0, // Use likes_count from backend
           'commentCount': post['comments_count'] ?? 0, // Use comments_count from backend
           'isLiked': post['is_liked_by_current_user'] == true, // Use the correct key from backend
           'isBookmarked': true, // By definition, posts on this page are bookmarked
           'timestamp': _formatTimestamp(post['created_at']), // Use created_at from backend
        }));
        _isLoading = false; // Yükleme bitti
      });

    } catch (e) {
      if (!mounted) return;
      print("Kaydedilen gönderiler çekilemedi: $e");
       setState(() {
         _errorMessage = 'Kaydedilenler yüklenirken bir hata oluştu: ${e.toString()}';
         _isLoading = false;
       });
    }
  }

  // Kaydedilenler sayfasında beğenme durumunu değiştirir
  void _toggleLike(String postId) async {
    if (_currentUserId == null) return; // Check if user ID is available
    final index = _savedPosts.indexWhere((p) => p['id'] == postId);
    if (index == -1) return;

    final post = _savedPosts[index];
    final bool wasLiked = post['isLiked'];
    final int oldLikeCount = post['likeCount'];
    final int postIdInt = int.tryParse(postId) ?? -1;

    if (postIdInt == -1) {
      print("Invalid postId for like toggle: $postId");
      return;
    }

    setState(() {
       post['isLiked'] = !wasLiked;
       post['likeCount'] = wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
     });

     print('Kaydedilen Gönderi ID $postId: Like Tapped. New Status: ${post['isLiked']}');

     try {
       final apiService = ApiService();
       if (wasLiked) {
         await apiService.unlikePost(postIdInt, _currentUserId!);
       } else {
         await apiService.likePost(postIdInt, _currentUserId!);
       }
     } catch (e) {
        print("Like/Unlike API call failed for $postId: $e");
        if (mounted) {
           // Check if the error is a 409 Conflict and the action was to LIKE (wasLiked was false)
           if (e.toString().contains('status 409') && !wasLiked) {
              print("Received 409 Conflict when trying to like. Assuming post is already liked.");
              // Update UI to reflect that the post is liked
              setState(() {
                 post['isLiked'] = true;
                 // Like count should already be correct from the initial fetch or previous interactions
              });
              ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Gönderi zaten beğenilmiş.')),
              );
           } else {
              // Revert UI on other API errors
              setState(() {
                 post['isLiked'] = wasLiked; // Revert like status
                 post['likeCount'] = oldLikeCount; // Revert like count
              });
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Beğenme işlemi başarısız oldu: ${e.toString()}')),
              );
           }
        }
     }
  }

  // Kaydedilenler sayfasında kaydetme durumunu değiştirir (Kaldırır)
  void _toggleBookmark(String postId) async {
     if (_currentUserId == null) return; // Check if user ID is available
     final index = _savedPosts.indexWhere((p) => p['id'] == postId);
     if (index == -1) return;

     final removedPost = _savedPosts[index]; 
     final int postIdInt = int.tryParse(postId) ?? -1;

     if (postIdInt == -1) {
       print("Invalid postId for bookmark toggle: $postId");
       return;
     }

     setState(() {
       _savedPosts.removeAt(index);
     });

     print('Kaydedilen Gönderi ID $postId: Bookmark Tapped (Removed from Saved).');

     try {
       final apiService = ApiService();
       await apiService.unbookmarkPost(postIdInt, _currentUserId!);
     } catch (e) {
        print("Unbookmark API call failed for $postId: $e");
        // Hata durumunda UI'a geri ekle
        if (mounted) {
           setState(() {
              _savedPosts.insert(index, removedPost); // Kaldırılan yere geri ekle
           });
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kayıt kaldırma işlemi başarısız oldu: ${e.toString()}')),
           );
        }
     }
  }

   // Profil sayfasına yönlendirme
   void _navigateToProfile(String username) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(username: username)
        ),
      );
   }

  // Zaman damgası formatlama (HomePage'den kopyalanabilir veya ortak bir helper'a taşınabilir)
   String _formatTimestamp(String? apiTimestamp) {
     if (apiTimestamp == null) return 'Bilinmeyen zaman';
     try {
       DateTime postTime = DateTime.parse(apiTimestamp).toLocal();
       Duration diff = DateTime.now().difference(postTime);
       if (diff.inDays > 7) return '${postTime.day.toString().padLeft(2, '0')}.${postTime.month.toString().padLeft(2, '0')}.${postTime.year}';
       if (diff.inDays >= 1) return '${diff.inDays} gün önce';
       if (diff.inHours >= 1) return '${diff.inHours} saat önce';
       if (diff.inMinutes >= 1) return '${diff.inMinutes} dakika önce';
       return 'Şimdi';
     } catch (e) {
       print("Timestamp formatlama hatası: $e");
       return apiTimestamp;
     }
   }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Temayı al

    return Scaffold(
      // backgroundColor: Colors.white, // Temadan almalı
      appBar: AppBar(
        title: const Text('Kaydedilenler'),
        // elevation: 0.5, // AppBarTheme'dan gelmeli
        // backgroundColor: Colors.white, // AppBarTheme'dan gelmeli
        // foregroundColor: Colors.black87, // AppBarTheme'dan gelmeli
      ),
      body: _buildSavedPostList(theme), // Temayı gönder
    );
  }

  // Kaydedilen gönderi listesini oluşturan widget
  Widget _buildSavedPostList(ThemeData theme) { // Temayı parametre olarak al
     final colorScheme = theme.colorScheme; // ColorScheme'i de alalım

    if (_isLoading) {
      // Yükleme göstergesinin rengini temadan al
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }

    if (_errorMessage != null) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Text(
             'Hata: $_errorMessage',
             style: const TextStyle(color: Colors.red),
             textAlign: TextAlign.center,
           ),
         ),
       );
    }

    if (_savedPosts.isEmpty) {
      return Center(
        child: Text(
          "Henüz kaydedilmiş gönderi yok.",
          style: TextStyle(color: theme.hintColor), // Tema rengi
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 10),
      itemCount: _savedPosts.length,
      itemBuilder: (context, index) {
        final postData = _savedPosts[index];
        // Use the new PostCard widget to render each post
        // Pass a callback to remove the post from the list when unbookmarked
        return PostCard(
          postData: postData,
          userId: _currentUserId!, // Pass the current user ID
        );
      },
    );
  }
}
