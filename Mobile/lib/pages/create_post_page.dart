import 'dart:io'; // File nesnesi için gerekli
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Resim seçmek için
import 'package:provider/provider.dart'; // UserState'e erişim için
import 'package:solara/services/api_service.dart'; // ApiService importu
import 'package:solara/services/user_state.dart'; // UserState importu

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

  // Galeriden veya kameradan resim seçmek için fonksiyon
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

  // Kullanıcıya kamera veya galeri seçeneği sunan bottom sheet
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

  // Seçilen resmi kaldırmak için fonksiyon
  void _clearImage() {
    setState(() {
      _imageFile = null;
    });
  }

  // Gönderiyi API'ye gönderme fonksiyonu
  Future<void> _submitPost() async {
     if (_textController.text.trim().isEmpty && _imageFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Lütfen bir metin yazın veya resim seçin.')),
       );
       return;
     }

     // --- Kullanıcı ID'sini al ---
     final userState = Provider.of<UserState>(context, listen: false);
     final currentUserId = userState.currentUser?['user_id'];

     if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Gönderi oluşturmak için giriş yapmış olmalısınız.')),
       );
       // İsteğe bağlı: Giriş sayfasına yönlendir
       return;
     }
     // --- Kullanıcı ID alındı ---


     setState(() { _isLoading = true; });

     try {
        String? imageUrl; // Resim URL'si (yüklenirse)

        // 1. Resim varsa yükle
        if (_imageFile != null) {
          print('Resim Yolu: ${_imageFile!.path}');
          // HATA DÜZELTME: uploadImage çağrısına userId eklendi
          imageUrl = await _apiService.uploadImage(_imageFile!, currentUserId);

          if (imageUrl == null) {
            // Resim yükleme başarısız olduysa işlemi durdur
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resim yüklenemedi. Gönderi oluşturulamadı.')),
              );
            }
             // Yükleme durumunu kapat ve fonksiyondan çık
            if (mounted) setState(() { _isLoading = false; });
            return;
          }
           print("Resim başarıyla yüklendi: $imageUrl");
        }

        // 2. Gönderi oluşturma isteğini gönder (metin ve varsa resim URL'si ile)
        print("Gönderi oluşturuluyor: userId=$currentUserId, text='${_textController.text.trim()}', imageUrl=$imageUrl");
        // HATA DÜZELTME: createPost çağrısına userId eklendi (ilk argüman)
        final response = await _apiService.createPost(
          currentUserId, // <-- userId eklendi (int)
          _textController.text.trim().isEmpty ? null : _textController.text.trim(), // Metin boşsa null gönder
          imageUrl         // Resim URL'si (varsa)
        );

        // 3. Yanıtı işle
        // Yanıtın formatı backend'e bağlı, burada {'success': true/false, 'message': '...'} varsayılıyor
        // ApiService içindeki _handleResponse zaten hata durumlarını yönetiyor (Exception fırlatıyor)
        // Bu yüzden buraya gelindiyse genellikle başarılıdır.
        if (mounted) {
           // Yanıttan mesajı alabiliriz (varsa)
           final message = (response is Map && response.containsKey('message'))
                           ? response['message']
                           : 'Gönderi başarıyla oluşturuldu!';

           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(message)),
           );
           // Başarılı olursa bir önceki sayfaya true değeriyle dön (HomePage'in yenilemesi için)
           Navigator.of(context).pop(true);
        }

     } catch (e) {
        // ApiService veya uploadImage'den gelen hatayı yakala
        print("Gönderi oluşturma hatası: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gönderi oluşturulamadı: ${e.toString()}')),
           );
        }
     } finally {
        // İşlem bitince (başarılı veya hatalı) yükleme durumunu kapat
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

    // Butonun aktif olup olmadığını kontrol et (hem yüklenmiyor hem de içerik var)
    final bool canPost = !_isLoading && (_textController.text.trim().isNotEmpty || _imageFile != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gönderi Oluştur'),
        // elevation: 0, // İsteğe bağlı: Gölgeyi kaldır
        leading: IconButton(
           icon: const Icon(Icons.close),
           onPressed: () => Navigator.of(context).pop(), // Bir önceki sayfaya dön
           tooltip: 'İptal',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: canPost ? _submitPost : null, // Aktif değilse null -> tıklanamaz
              style: TextButton.styleFrom(
                foregroundColor: Colors.white, // Metin rengi
                backgroundColor: canPost ? colorScheme.primary : Colors.grey.shade400, // Arkaplan rengi (aktif/pasif)
                disabledForegroundColor: Colors.white.withOpacity(0.7), // Pasif metin rengi
                disabledBackgroundColor: Colors.grey.shade400, // Pasif arkaplan
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
                // Karakter sayacını daha küçük ve sağ altta göster
                return Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                     '$currentLength / $maxLength',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                );
              },
              onChanged: (text) { setState(() {}); }, // Buton durumunu güncellemek için
            ),
            const SizedBox(height: 20),

            if (_imageFile == null) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Resim Ekle'),
                onPressed: _isLoading ? null : () => _showImageSourceActionSheet(context), // Yükleniyorsa butonu pasif yap
                 style: OutlinedButton.styleFrom(
                   // Düğmenin yüksekliğini ve iç boşluğunu ayarlayabilirsiniz
                   minimumSize: const Size(double.infinity, 45), // Genişliği doldur, minimum yükseklik
                   side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)), // Kenarlık rengi
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
                        onPressed: _isLoading ? null : _clearImage, // Yükleniyorsa pasif yap
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: 'Resmi Kaldır',
                      ),
                    ),
                  ),
                ],
              ),
               // İsteğe bağlı: Resim seçiliyken de metin ekleme/düzenleme devam edebilir.
               const SizedBox(height: 10),
               OutlinedButton.icon( // Resmi değiştirme butonu
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
    );
  }
}