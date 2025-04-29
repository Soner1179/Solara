import 'dart:math'; // Simülasyon için (kaldırılabilir)
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // RichText için
import 'package:solara/pages/profile_page.dart'; // Profil sayfasına gitmek için
import 'package:solara/services/api_service.dart'; // ApiService importu <--- EKLENDİ

// Sabitleri ortak bir dosyadan almak en iyisidir.
// import 'package:solara/constants/app_assets.dart';

// Şimdilik sabitleri burada tutuyoruz:
const String _notFoundImage = 'assets/images/not-found.png';
const String postPlaceholderIcon = 'assets/images/post_placeholder.png';
const String likeIcon = 'assets/images/like.png';
const String likeRedIcon = 'assets/images/like(red).png';
const String commentIcon = 'assets/images/comment.png';
// const String bookmarkBlackIcon = 'assets/images/bookmark(black).png'; // Bu sayfada hep dolu ikon
const String bookmarkTappedIcon = 'assets/images/bookmark(tapped).png';
// const String _currentUserUsername = "soner1179"; // Bu sayfada doğrudan kullanılmıyor


class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  List<Map<String, dynamic>> _savedPosts = [];
  bool _isLoading = true;
  String? _errorMessage; // Added error message state

  // TODO: Get actual current user ID
  final int _currentUserId = 1; // Placeholder current user ID

  @override
  void initState() {
    super.initState();
    _fetchSavedPosts();
  }

  Future<void> _fetchSavedPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous error
      _savedPosts = []; // Clear previous data
    });

    try {
      final apiService = ApiService();
      // Use the fetchSavedPosts function from ApiService
      final List<dynamic> data = await apiService.fetchSavedPosts(_currentUserId);

      if (!mounted) return;

      setState(() {
        // Map the fetched data to the desired format (similar to home_page.dart)
        _savedPosts = List<Map<String, dynamic>>.from(data.map((post) => {
           'id': post['post_id'].toString(), // Use post_id from backend
           'user_id': post['user_id'], // Keep user_id
           'username': post['username'] ?? 'bilinmeyen', // Use username from backend
           'avatarUrl': post['profile_picture_url'] ?? _notFoundImage, // Use profile_picture_url from backend
           // Construct full image URL if it's a relative path from backend uploads
           'imageUrl': (post['image_url'] != null && post['image_url'].startsWith('/uploads/'))
               ? 'http://192.168.1.152:5000${post['image_url']}' // Prepend backend server base URL
               : post['image_url'] ?? postPlaceholderIcon, // Use as is or use placeholder
           'caption': post['content_text'] ?? '', // Use content_text from backend
           'likeCount': post['likes_count'] ?? 0, // Use likes_count from backend
           'commentCount': post['comments_count'] ?? 0, // Use comments_count from backend
           'isLiked': post['is_liked_by_user'] ?? false, // Assuming backend provides this
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
  void _toggleLike(String postId) async { // Made async
    final index = _savedPosts.indexWhere((p) => p['id'] == postId);
    if (index == -1) return;

    final post = _savedPosts[index];
    final bool wasLiked = post['isLiked'];
    final int oldLikeCount = post['likeCount'];
    final int postIdInt = int.tryParse(postId) ?? -1; // Convert postId to int

    if (postIdInt == -1) {
      print("Invalid postId for like toggle: $postId");
      return;
    }

    // Optimistic UI update
    setState(() {
       post['isLiked'] = !wasLiked;
       post['likeCount'] = wasLiked ? oldLikeCount - 1 : oldLikeCount + 1;
     });

     print('Kaydedilen Gönderi ID $postId: Like Tapped. New Status: ${post['isLiked']}');

     try {
       final apiService = ApiService();
       if (wasLiked) {
         await apiService.unlikePost(postIdInt, _currentUserId);
       } else {
         await apiService.likePost(postIdInt, _currentUserId);
       }
     } catch (e) {
        print("Like/Unlike API call failed for $postId: $e");
        // Revert UI on API error
        if (mounted) {
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

  // Kaydedilenler sayfasında kaydetme durumunu değiştirir (Kaldırır)
  void _toggleBookmark(String postId) async { // Made async
     final index = _savedPosts.indexWhere((p) => p['id'] == postId);
     if (index == -1) return;

     final removedPost = _savedPosts[index]; // Geri almak için sakla (opsiyonel)
     final int postIdInt = int.tryParse(postId) ?? -1; // Convert postId to int

     if (postIdInt == -1) {
       print("Invalid postId for bookmark toggle: $postId");
       return;
     }

     // Optimistic UI update: Remove from list
     setState(() {
       _savedPosts.removeAt(index);
     });

     print('Kaydedilen Gönderi ID $postId: Bookmark Tapped (Removed from Saved).');

     try {
       final apiService = ApiService();
       await apiService.unbookmarkPost(postIdInt, _currentUserId);
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

    // HomePage'deki _buildPostList'e çok benzer yapı.
    // İDEAL: Bu kısmı `PostCard` widget'ına devretmek.
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 10),
      itemCount: _savedPosts.length,
      itemBuilder: (context, index) {
        final postData = _savedPosts[index];
        // Verileri değişkene ata
        String postId = postData['id'];
        String postUsername = postData['username'] ?? 'bilinmeyen';
        String? postLocation = postData['location'];
        String postAvatarUrl = postData['avatarUrl'] ?? _notFoundImage;
        String postImageUrl = postData['imageUrl'] ?? postPlaceholderIcon;
        String postCaption = postData['caption'] ?? '';
        int likeCount = postData['likeCount'] ?? 0;
        int commentCount = postData['comments_count'] ?? 0; // Use comments_count
        bool isLiked = postData['isLiked'] ?? false;
        // isBookmarked bu sayfada hep true başlar, basınca kaldırılır
        bool isBookmarked = true;
        String timestamp = postData['timestamp'] ?? ''; // Gerçek API'de _formatTimestamp kullanın

        // Gönderi kartı için tema renkleri (HomePage'deki gibi)
        Color? textColor = theme.textTheme.bodyMedium?.color;
        Color? secondaryTextColor = theme.textTheme.bodySmall?.color?.withOpacity(0.7);
        Color? iconColor = theme.iconTheme.color;
        Color? likeColor = isLiked ? Colors.redAccent : iconColor;
        Color? bookmarkColor = isBookmarked ? colorScheme.primary : iconColor; // Kaydedilenler sayfasında hep dolu renk

        // Gönderi kartı (HomePage'deki yapıya benzer şekilde tema renkleri uygulandı)
         return Container(
           // color: theme.cardColor, // İsteğe bağlı kart arkaplanı
           margin: const EdgeInsets.symmetric(vertical: 8.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // 1. Başlık (Avatar, Kullanıcı Adı, Konum, ...)
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                 child: Row(
                   children: [
                     GestureDetector(
                       onTap: () => _navigateToProfile(postUsername),
                       child: CircleAvatar(
                         radius: 18,
                         backgroundColor: colorScheme.secondaryContainer, // Tema rengi
                         backgroundImage: AssetImage(postAvatarUrl),
                         onBackgroundImageError: (e,s) => print("Saved Post avatar error ($postAvatarUrl): $e"),
                       ),
                     ),
                     const SizedBox(width: 10),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           GestureDetector(
                             onTap: () => _navigateToProfile(postUsername),
                             child: Text(
                               postUsername,
                               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                             ),
                           ),
                           if (postLocation != null && postLocation.isNotEmpty)
                             Text(postLocation, style: TextStyle(fontSize: 12, color: secondaryTextColor),),
                         ],
                       ),
                     ),
                     // Kaydedilenler sayfasında 'more' butonu? (Opsiyonel)
                     // IconButton( icon: Icon(Icons.more_vert, color: iconColor?.withOpacity(0.7)), onPressed: () {},),
                   ],
                 ),
               ),
               // 2. Gönderi Resmi
               AspectRatio(
                 aspectRatio: 1.0,
                 child: Container(
                   color: theme.dividerColor, // Yüklenirken arka plan
                    child: FadeInImage.assetNetwork(
                      placeholder: postPlaceholderIcon,
                      image: postImageUrl,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, stackTrace) {
                        print('Saved Post image network error ($postImageUrl): $error');
                        return Center(child: Image.asset(_notFoundImage, fit: BoxFit.contain, width: 100, height: 100, color: theme.hintColor));
                      },
                      placeholderErrorBuilder: (context, error, stackTrace) {
                        print('Saved Post placeholder error ($postPlaceholderIcon): $error');
                        return Center(child: Icon(Icons.broken_image, size: 50, color: theme.hintColor));
                      },
                    ),
                  ),
               ),
               // 3. Eylem Butonları
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
                 child: Row(
                   children: [
                     IconButton(
                       icon: Image.asset(isLiked ? likeRedIcon : likeIcon, width: 26, height: 26, color: likeColor), // Tema rengi
                       tooltip: 'Beğen',
                       onPressed: () => _toggleLike(postId),
                     ),
                     IconButton(
                       icon: Image.asset(commentIcon, width: 26, height: 26, color: iconColor), // Tema rengi
                       tooltip: 'Yorum Yap',
                       onPressed: () {
                         print('Saved Post ID $postId: Comment Tapped');
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Yorumlar bölümü yakında'), duration: Duration(seconds: 1)),
                         );
                       },
                     ),
                     const Spacer(),
                     IconButton(
                       // Kaydedilenler sayfasında her zaman dolu ikonu gösteririz,
                       // basıldığında kayıttan çıkarılır (_toggleBookmark ile)
                       icon: Image.asset(bookmarkTappedIcon, width: 26, height: 26, color: bookmarkColor), // Tema rengi (hep aktif)
                       tooltip: 'Kaydetmeyi Kaldır',
                       onPressed: () => _toggleBookmark(postId),
                     ),
                   ],
                 ),
               ),
               // 4. Detaylar (HomePage'deki gibi tema renkleri uygulandı)
               Padding(
                 padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     if (likeCount > 0)
                       Padding(
                         padding: const EdgeInsets.only(bottom: 4.0),
                         child: Text('$likeCount beğenme', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), // Tema rengi
                       ),
                     if (postCaption.isNotEmpty)
                       Padding(
                         padding: const EdgeInsets.only(bottom: 4.0),
                         child: RichText( // Kullanıcı adına tıklama için RichText
                           text: TextSpan(
                             style: TextStyle(color: textColor, fontSize: 14, height: 1.3), // Tema rengi
                             children: [
                               TextSpan(
                                 text: '$postUsername ',
                                 style: const TextStyle(fontWeight: FontWeight.bold),
                                  recognizer: TapGestureRecognizer()..onTap = () => _navigateToProfile(postUsername),
                               ),
                               TextSpan(text: postCaption),
                             ],
                           ),
                           maxLines: 2,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                     if (commentCount > 0)
                       Padding(
                         padding: const EdgeInsets.only(bottom: 4.0),
                         child: InkWell(
                           onTap: (){
                              print('Saved Post ID $postId: View Comments Tapped');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Yorumlar bölümü yakında'), duration: Duration(seconds: 1)),
                              );
                            },
                           child: Text(
                              commentCount == 1 ? '1 yorumu gör' : '$commentCount yorumun tümünü gör',
                              style: TextStyle(color: secondaryTextColor), // Tema rengi
                           ),
                         ),
                      ),
                     Text(timestamp, style: TextStyle(color: secondaryTextColor, fontSize: 12)), // Tema rengi
                   ],
                 ),
               ),
             ],
           ),
         );
      },
    );
  }
}
