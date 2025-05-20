// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:solara/constants/api_constants.dart'; // Varsayılan import
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:flutter_tts/flutter_tts.dart'; // Import for text-to-speech
import 'package:solara/services/api_service.dart'; // Import ApiService
import 'package:solara/services/user_state.dart'; // Import UserState

// --- Asset Paths ---
const String _iconPath = 'assets/images/';
const String postPlaceholderIcon = '${_iconPath}post_placeholder.png'; // Resim yüklenirken gösterilecek varsayılan resim
const String defaultAvatar = '${_iconPath}default-avatar.png'; // Profil resmi için varsayılan avatar
const String likeIcon = '${_iconPath}like.png';
const String likeRedIcon = '${_iconPath}like(red).png';
const String commentIcon = '${_iconPath}comment.png';
const String _notFoundImage = '${_iconPath}not-found.png'; // Resim bulunamadığında gösterilecek resim
// --- End Asset Paths ---

class PostCard extends StatefulWidget { // Changed to StatefulWidget
  final Map<String, dynamic> postData;
  final int userId; // Add userId

  const PostCard({
    Key? key,
    required this.postData,
    required this.userId, // Add userId to constructor
  }) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState(); // Create State
}

class _PostCardState extends State<PostCard> { // Created State class
  late FlutterTts flutterTts; // Declare FlutterTts instance
  final ApiService apiService = ApiService(); // Add ApiService instance
  late bool _isLiked;
  late int _likeCount;
  late bool _isBookmarked; // Add isBookmarked state

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts(); // Initialize FlutterTts
    _initTts(); // Initialize TTS settings
    _setTtsListeners(); // Set up TTS listeners
    _isLiked = widget.postData['isLiked'] ?? false;
    _likeCount = widget.postData['likeCount'] ?? 0;
    _isBookmarked = widget.postData['isBookmarked'] ?? false; // Initialize isBookmarked state
  }

  @override
  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the internal state if the incoming postData has changed
    if (widget.postData['isLiked'] != _isLiked) {
      setState(() {
        _isLiked = widget.postData['isLiked'] ?? false;
      });
    }
    if (widget.postData['likeCount'] != _likeCount) {
       setState(() {
         _likeCount = widget.postData['likeCount'] ?? 0;
       });
    }
    if (widget.postData['isBookmarked'] != _isBookmarked) {
       setState(() {
         _isBookmarked = widget.postData['isBookmarked'] ?? false;
       });
    }
  }


  Future<void> _initTts() async {
    await flutterTts.setLanguage("tr-TR"); // Set language to Turkish
    await flutterTts.setPitch(1.0); // Set pitch
    await flutterTts.setSpeechRate(0.5); // Set speech rate
  }

  void _setTtsListeners() {
    flutterTts.setStartHandler(() {
      print("TTS: Speech Started");
    });

    flutterTts.setCompletionHandler(() {
      print("TTS: Speech Completed");
    });

    flutterTts.setErrorHandler((msg) {
      print("TTS Error: $msg");
    });

    flutterTts.setCancelHandler(() {
      print("TTS: Speech Cancelled");
    });

    flutterTts.setContinueHandler(() {
      print("TTS: Speech Continued");
    });

    flutterTts.setProgressHandler((text, start, end, word) {
      // Optional: Log progress if needed
      // print("TTS Progress: $word ($start-$end)");
    });
  }


  Future<void> _speak(String text) async {
    print('Attempting to speak: "$text"'); // Add logging
    var isLanguageAvailable = await flutterTts.isLanguageAvailable("tr-TR");
    print('TTS Language "tr-TR" available: $isLanguageAvailable');

    var engines = await flutterTts.getEngines;
    print('Available TTS Engines: $engines');

    var voices = await flutterTts.getVoices;
    print('Available TTS Voices: $voices');

    if (text.isNotEmpty) {
      try {
        var result = await flutterTts.speak(text); // Speak the text
        if (result == 1) {
          print('flutterTts.speak called successfully.'); // Add logging
        } else {
          print('flutterTts.speak call failed with result: $result');
        }
      } catch (e) {
        print('Error in flutterTts.speak: $e'); // Log any errors from speak
      }
    } else {
      print('Text to speak is empty.'); // Log if text is empty
    }
  }

  Future<void> _stopSpeaking() async {
    await flutterTts.stop(); // Stop speaking
  }

  @override
  void dispose() {
    flutterTts.stop(); // Stop speaking when disposing
    super.dispose();
  }

  String? _getImageUrl(String? relativeOrAbsoluteUrl) {
    if (relativeOrAbsoluteUrl == null || relativeOrAbsoluteUrl.isEmpty) {
      return null;
    }
    if (relativeOrAbsoluteUrl.startsWith('http')) {
      return relativeOrAbsoluteUrl;
    }
    final serverBase = ApiEndpoints.baseUrl.replaceAll('/api', '');
    final fullUrl = '$serverBase$relativeOrAbsoluteUrl';
    if (fullUrl.startsWith('http://') || fullUrl.startsWith('https://')) {
      return fullUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String postUsername = widget.postData['username'] ?? 'bilinmeyen'; // Access postData via widget
    final String? postAvatarUrl = _getImageUrl(widget.postData['avatarUrl']); // Access postData via widget
    final String? postImageUrl = _getImageUrl(widget.postData['imageUrl']); // Access postData via widget
    final String postCaption = widget.postData['caption'] ?? ''; // Access postData via widget
    final int commentCount = widget.postData['commentCount'] ?? 0; // Access postData via widget
    // final bool isBookmarked = widget.postData['isBookmarked'] ?? false; // Not shown in this design
    final String timestampString = widget.postData['timestamp'] ?? ''; // Access postData via widget

    // Function to format the timestamp
    String formatTimestamp(String timestampStr) {
      if (timestampStr.isEmpty) {
        return '';
      }
      try {
        // Attempt to parse the timestamp string
        final DateTime postTime = DateTime.parse(timestampStr);
        final DateTime now = DateTime.now();
        final Duration difference = now.difference(postTime);

        if (difference.inMinutes < 1) {
          return 'Az önce';
        } else if (difference.inHours < 1) {
          return '${difference.inMinutes} dakika önce';
        } else if (difference.inDays < 1) {
          return '${difference.inHours} saat önce';
        } else if (difference.inDays < 7) {
           return '${difference.inDays} gün önce';
        } else {
          // Format as "28 Kasım 2025" using Turkish locale
          return DateFormat('d MMMM yyyy', 'tr').format(postTime);
        }
      } catch (e) {
        // If initial parsing fails, try alternative formats
        print('Error parsing timestamp with default format: $e. Attempting alternative parsing.');
        try {
           // Attempt parsing with ISO 8601 format with timezone
           DateTime postTime = DateFormat("yyyy-MM-ddTHH:mm:ssZ").parse(timestampStr, true).toLocal();
           final DateTime now = DateTime.now();
           final Duration difference = now.difference(postTime);

            if (difference.inMinutes < 1) {
              return 'Az önce';
            } else if (difference.inHours < 1) {
              return '${difference.inMinutes} dakika önce';
            } else if (difference.inDays < 1) {
              return '${difference.inHours} saat önce';
            } else if (difference.inDays < 7) {
               return '${difference.inDays} gün önce';
            } else {
              // Format as "28 Kasım 2025" using Turkish locale
              // Manually construct the date string to ensure Turkish month names
              const List<String> turkishMonthNames = [
                '', // Months are 1-indexed
                'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
                'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
              ];
              final String monthName = turkishMonthNames[postTime.month];
              return '${postTime.day} $monthName ${postTime.year}';
            }
        } catch (e2) {
           print('Error parsing timestamp with ISO 8601 format: $e2. Attempting d.M.yyyy format.');
           try {
              // Attempt parsing with "d.M.yyyy" format
              DateTime postTime = DateFormat("d.M.yyyy").parse(timestampStr);
              final DateTime now = DateTime.now();
              final Duration difference = now.difference(postTime);

               if (difference.inMinutes < 1) {
                 return 'Az önce';
               } else if (difference.inHours < 1) {
                 return '${difference.inMinutes} dakika önce';
               } else if (difference.inDays < 1) {
                 return '${difference.inHours} saat önce';
               } else if (difference.inDays < 7) {
                  return '${difference.inDays} gün önce';
               } else {
                 // Format as "28 Kasım 2025" using Turkish locale
                 // Manually construct the date string to ensure Turkish month names
                 const List<String> turkishMonthNames = [
                   '', // Months are 1-indexed
                   'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
                   'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
                 ];
                 final String monthName = turkishMonthNames[postTime.month];
                 return '${postTime.day} $monthName ${postTime.year}';
               }
           } catch (e3) {
              print('Error parsing timestamp with d.M.yyyy format: $e3');
              return timestampStr; // Return original string if all parsing fails
           }
        }
      }
    }

    final String formattedTimestamp = formatTimestamp(timestampString);

    final Color textColor = Colors.black87; // Based on image
    final Color secondaryTextColor = Colors.grey[600]!; // Based on image

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      elevation: 3.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(100, 135, 135, 135), // Orange
                  Color.fromARGB(100, 148, 187, 233), // Yellow
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: GestureDetector(
              onTap: () {
                // Navigate to the user's profile page
                Navigator.pushNamed(
                  context,
                  '/profile', // Assuming '/profile' is the route name for the profile page
                  arguments: widget.postData['username'], // Pass the username to the profile page
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.8),
                    child: ClipOval(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: (postAvatarUrl != null && postAvatarUrl.startsWith('http'))
                            ? FadeInImage.assetNetwork(
                                placeholder: defaultAvatar,
                                image: postAvatarUrl,
                                fit: BoxFit.cover,
                                imageErrorBuilder: (context, error, stackTrace) {
                                  return Image.asset(defaultAvatar, fit: BoxFit.cover);
                                },
                                placeholderErrorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.person, size: 20, color: Colors.grey[600]);
                                },
                              )
                            : Image.asset(
                                defaultAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.person, size: 20, color: Colors.grey[600]);
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          postUsername,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formattedTimestamp, // Using formatted timestamp
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.8), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Post Image (Normal)
          if (postImageUrl != null && postImageUrl.isNotEmpty)
            FadeInImage.assetNetwork(
              placeholder: postPlaceholderIcon,
                image: postImageUrl,
                fit: BoxFit.fill,
                width: double.infinity,
                height: 350.0, // Adjusted height based on image
                imageErrorBuilder: (context, error, stackTrace) => Container(
                  height: 350.0,
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(_notFoundImage, width: 60, height: 60, color: theme.colorScheme.error.withOpacity(0.6)),
                    const SizedBox(height: 8),
                    Text("Resim yüklenemedi", style: TextStyle(color: theme.colorScheme.error.withOpacity(0.7))),
                  ],
                ),
              ),
              placeholderErrorBuilder: (context, error, stackTrace) => Container(
                height: 200.0,
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.1),
                alignment: Alignment.center,
                child: Icon(Icons.image_not_supported_outlined, size:50, color: secondaryTextColor.withOpacity(0.5))
              ),
            ),

          const SizedBox(height: 15.0), // Added space between image and description

          // Post Content (Summary and Read More)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  postCaption,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor, height: 1.4, fontSize: 15),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                if (postCaption.length > 200) ...[ // Check if caption length exceeds a threshold
                  const SizedBox(height: 8),
                  Text(
                    'Devamını oku',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.blueGrey[700]),
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute icons evenly
              children: [
                Row( // Wrap icon and text in a Row
                  children: [
                    IconButton(
                      icon: Image.asset(_isLiked ? likeRedIcon : likeIcon, width: 28, height: 28, color: _isLiked ? Colors.red : secondaryTextColor), // Change color based on liked state, Increased size
                      iconSize: 28, // Increased size
                      tooltip: _isLiked ? 'Beğenmekten Vazgeç' : 'Beğen', // Update tooltip based on state
                      onPressed: () async {
                        final int? postId = int.tryParse(widget.postData['id']?.toString() ?? '');
                        if (postId == null) {
                          print('Error: Post ID is null or invalid for liking.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('İşlem başarısız: Geçersiz gönderi IDsi.')),
                          );
                          return;
                        }
                        final userState = Provider.of<UserState>(context, listen: false);
                        final currentUserId = userState.currentUser?['user_id'];
                        if (currentUserId == null) {
                          print("Error: User must be logged in to like posts.");
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beğenmek için giriş yapmalısınız.')));
                          return;
                        }

                        try {
                          if (_isLiked) {
                            // If currently liked, unlike it
                            await apiService.unlikePost(postId, currentUserId);
                            print('Post unliked successfully!');
                            setState(() {
                              _isLiked = false;
                              _likeCount--;
                            });
                          } else {
                            // If not currently liked, like it
                            await apiService.likePost(postId, currentUserId);
                            print('Post liked successfully!');
                            setState(() {
                              _isLiked = true;
                              _likeCount++;
                            });
                          }
                        } catch (e) {
                          print('Error toggling like for post: $e');
                          // Show error message to user
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Beğenme işlemi başarısız: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                    Text(
                      _likeCount.toString(), // Display like count from state
                      style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor, fontSize: 16), // Increased font size
                    ),
                  ],
                ),
                Row( // Wrap icon and text in a Row
                  children: [
                    IconButton(
                      icon: Image.asset(commentIcon, width: 26, height: 26, color: secondaryTextColor), // Grey color based on image, Increased size
                      iconSize: 26, // Increased size
                      tooltip: 'Yorum Yap',
                      onPressed: () {
                        final int? postId = int.tryParse(widget.postData['id']?.toString() ?? '');
                         if (postId == null) {
                           print('Error: Post ID is null or invalid for commenting.');
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('İşlem başarısız: Geçersiz gönderi IDsi.')),
                           );
                           return;
                         }
                        // TODO: Implement comment functionality (e.g., show a dialog or navigate to comments page)
                        print('Comment button pressed for post $postId');
                        // Example: Navigate to comments page (assuming a route exists)
                         Navigator.pushNamed(
                           context,
                           '/comments', // Assuming '/comments' is the route name for the comments page
                           arguments: postId, // Pass the post ID to the comments page
                         );
                      },
                    ),
                    Text(
                      commentCount.toString(), // Display comment count
                      style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor, fontSize: 16), // Increased font size
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: secondaryTextColor),
                  tooltip: 'Daha Fazla',
                  onSelected: (String result) async { // Make onSelected async
                    print('PopupMenuButton onSelected: $result'); // Add logging
                    final int? postId = int.tryParse(widget.postData['id']?.toString() ?? '');
                    if (postId == null) {
                      print('Error: Post ID is null or invalid for bookmarking.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İşlem başarısız: Geçersiz gönderi IDsi.')),
                      );
                      return;
                    }
                    final userState = Provider.of<UserState>(context, listen: false);
                    final currentUserId = userState.currentUser?['user_id'];
                    if (currentUserId == null) {
                      print("Error: User must be logged in to bookmark posts.");
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetmek için giriş yapmalısınız.')));
                      return;
                    }

                    if (result == 'kaydet') {
                      print('Selected: Kaydet'); // Add logging for Kaydet
                      print('Current _isBookmarked state: $_isBookmarked'); // Log current state
                      try {
                        if (_isBookmarked) {
                          // If currently bookmarked, unbookmark it
                          print('Attempting to unbookmark post $postId'); // Log action
                          try {
                            final dynamic unbookmarkResult = await apiService.unbookmarkPost(postId, currentUserId);
                            print('Unbookmark API result: $unbookmarkResult'); // Log API result
                            print('Post unbookmarked successfully!');
                            setState(() {
                              _isBookmarked = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gönderi kaydedilenlerden kaldırıldı.')),
                            );
                          } catch (e) {
                            // Check if the error is a 404 (Not Found)
                            if (e.toString().contains('status 404')) {
                              print('Unbookmark API returned 404. Assuming already unsaved.');
                              setState(() {
                                _isBookmarked = false; // Sync state with backend
                              });
                               ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gönderi zaten kaydedilenlerde değil.')),
                              );
                            } else {
                              print('Error unbookmarking post: ${e.toString()}');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Kaydedilenlerden kaldırma işlemi başarısız: ${e.toString()}')),
                              );
                              // Do not change _isBookmarked state on other errors
                            }
                          }
                        } else {
                          // If not currently bookmarked, bookmark it
                          print('Attempting to bookmark post $postId'); // Log action
                          try {
                            final dynamic bookmarkResult = await apiService.bookmarkPost(postId, currentUserId);
                            print('Bookmark API result: $bookmarkResult'); // Log API result
                            print('Post bookmarked successfully!');
                            setState(() {
                              _isBookmarked = true;
                            });
                             ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gönderi kaydedildi.')),
                            );
                          } catch (e) {
                             print('Error bookmarking post: ${e.toString()}');
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Kaydetme işlemi başarısız: ${e.toString()}')),
                             );
                             // Do not change _isBookmarked state on errors
                          }
                        }
                         print('New _isBookmarked state after potential setState: $_isBookmarked'); // Log new state
                      } catch (e) {
                        // This outer catch block will catch errors from the initial postId/userId checks
                        print('Error in bookmark logic (initial checks): ${e.toString()}');
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('İşlem sırasında bir hata oluştu: ${e.toString()}')),
                         );
                      }
                    }
                    // Removed 'sesli_oku' from here, will handle tap directly on the item
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>( // Make this a PopupMenuItem
                      value: 'kaydet',
                      child: Text(_isBookmarked ? 'Kaydedildi' : 'Kaydet'), // Update text based on bookmark status
                    ),
                    PopupMenuItem<String>( // Use PopupMenuItem for 'Sesli Oku'
                      value: 'sesli_oku',
                      child: InkWell( // Wrap Text with InkWell
                        onTap: () {
                          print('Sesli Oku InkWell tapped.'); // Add logging
                          _speak(postCaption); // Call _speak with postCaption
                          Navigator.pop(context); // Close the popup menu
                        },
                        child: const Text('Sesli Oku'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
