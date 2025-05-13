import 'dart:io'; // File nesnesi için gerekli
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Resim seçmek için
import 'package:provider/provider.dart'; // UserState'e erişim için
import 'package:solara/services/api_service.dart'; // ApiService importu
import 'package:solara/services/user_state.dart'; // UserState importu
import 'package:solara/pages/home_page.dart'; // HomePage'e navigasyon için
import 'package:solara/pages/chats_list_page.dart'; // ChatsListPage'e navigasyon için
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

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile; // Seçilen resim dosyasını tutacak değişken (nullable)
  bool _isLoading = false; // Paylaşım işlemi sırasında yükleme durumu
  final ApiService _apiService = ApiService(); // ApiService instance

  // --- Bottom Navigation Bar için Gerekli Kısım (home_page.dart'tan uyarlandı) ---
  int _selectedIndex = 2; // "Oluştur" sekmesi aktif

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
      case 2: // Oluştur - Zaten buradayız
        break;
      case 3: // Bildirimler
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 3)),
          (Route<dynamic> route) => false,
        );
        break;
      case 4: // Mesajlar
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatsListPage()),
        );
        break;
    }
  }
  // --- End Bottom Navigation Bar için Gerekli Kısım ---


  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Resim seçilemedi: ${e.toString()}')),
           );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamerayı Kullan'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
    });
  }

  Future<void> _submitPost() async {
     if (_textController.text.trim().isEmpty && _imageFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Lütfen bir metin yazın veya resim seçin.')),
       );
       return;
     }

     final userState = Provider.of<UserState>(context, listen: false);
     final currentUserId = userState.currentUser?['user_id'];

     if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Gönderi oluşturmak için giriş yapmış olmalısınız.')),
       );
       return;
     }

     setState(() { _isLoading = true; });

     try {
        String? imageUrl;

        if (_imageFile != null) {
          print('Resim Yolu: ${_imageFile!.path}');
          imageUrl = await _apiService.uploadImage(_imageFile!, currentUserId);

          if (imageUrl == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resim yüklenemedi. Gönderi oluşturulamadı.')),
              );
            }
            if (mounted) setState(() { _isLoading = false; });
            return;
          }
           print("Resim başarıyla yüklendi: $imageUrl");
        }

        print("Gönderi oluşturuluyor: userId=$currentUserId, text='${_textController.text.trim()}', imageUrl=$imageUrl");
        final response = await _apiService.createPost(
          currentUserId,
          _textController.text.trim().isEmpty ? null : _textController.text.trim(),
          imageUrl
        );

        if (mounted) {
           final message = (response is Map && response.containsKey('message'))
                           ? response['message']
                           : 'Gönderi başarıyla oluşturuldu!';

           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(message)),
           );
           Navigator.of(context).pop(true); // HomePage'in yenilemesi için true değeriyle dön
        }

     } catch (e) {
        print("Gönderi oluşturma hatası: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gönderi oluşturulamadı: ${e.toString()}')),
           );
        }
     } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
     }
  }


  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget postButtonChild = _isLoading
        ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator( strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),
          )
        : const Text('Paylaş');

    final bool canPost = !_isLoading && (_textController.text.trim().isNotEmpty || _imageFile != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gönderi Oluştur'),
        leading: IconButton(
           icon: const Icon(Icons.close),
           onPressed: () => Navigator.of(context).pop(),
           tooltip: 'İptal',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: canPost ? _submitPost : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: canPost ? colorScheme.primary : Colors.grey.shade400,
                disabledForegroundColor: Colors.white.withOpacity(0.7),
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              child: postButtonChild,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Ne düşünüyorsun?',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 500,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                     '$currentLength / $maxLength',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                );
              },
              onChanged: (text) { setState(() {}); },
            ),
            const SizedBox(height: 20),

            if (_imageFile == null) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Resim Ekle'),
                onPressed: _isLoading ? null : () => _showImageSourceActionSheet(context),
                 style: OutlinedButton.styleFrom(
                   minimumSize: const Size(double.infinity, 45),
                   side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                 ),
              ),
            ] else ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.file( _imageFile!, fit: BoxFit.cover, width: double.infinity,),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      radius: 16, backgroundColor: Colors.black.withOpacity(0.6),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: _isLoading ? null : _clearImage,
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: 'Resmi Kaldır',
                      ),
                    ),
                  ),
                ],
              ),
               const SizedBox(height: 10),
               OutlinedButton.icon(
                icon: const Icon(Icons.sync_alt_outlined),
                label: const Text('Resmi Değiştir'),
                onPressed: _isLoading ? null : () => _showImageSourceActionSheet(context),
                 style: OutlinedButton.styleFrom(
                   minimumSize: const Size(double.infinity, 45),
                   side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                 ),
              ),
            ],
             const SizedBox(height: 30),
          ],
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
}
