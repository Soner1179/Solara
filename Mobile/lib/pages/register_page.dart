// lib/pages/register_page.dart
import 'dart:convert'; // JSON işlemleri için gerekli.
import 'package:flutter/material.dart'; // Flutter'ın Material Design widget'ları.
// import 'package:flutter_svg/flutter_svg.dart'; // SVG için gerekli değilse kaldırılabilir.
import 'package:http/http.dart' as http; // HTTP istekleri yapmak için.
import 'dart:async';
import 'package:provider/provider.dart'; // Provider paketi için import
import 'package:solara/services/api_service.dart'; // ApiService importu
import 'package:solara/services/user_state.dart'; // UserState importu

// Proje adınız farklıysa 'solara' kısmını değiştirin.
// !!! BU DOSYANIN İÇERİĞİNİN DOĞRU OLDUĞUNDAN EMİN OLUN !!!
// Özellikle baseUrl'in http://<BILGISAYARIN_YEREL_IP>:5000 şeklinde olması lazım.
import 'package:solara/constants/api_constants.dart';

// RegisterPage: Kullanıcı kayıt ekranını temsil eden Stateful widget.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key}); // Kurucu metot.

  @override
  // State nesnesini oluşturur.
  State<RegisterPage> createState() => _RegisterPageState();
}

// _RegisterPageState: RegisterPage'in durumunu yöneten sınıf.
class _RegisterPageState extends State<RegisterPage> {
  // Kullanıcı adı giriş alanı için denetleyici.
  final _usernameController = TextEditingController(); // EKLENDİ
  // E-posta giriş alanı için denetleyici.
  final _emailController = TextEditingController();
  // Şifre giriş alanı için denetleyici.
  final _passwordController = TextEditingController();
  // Şifre onaylama alanı için denetleyici.
  final _confirmPasswordController = TextEditingController();


  // İlk şifre alanının görünürlüğünü kontrol eder.
  bool _obscureText1 = true;
  // İkinci şifre alanının görünürlüğünü kontrol eder.
  bool _obscureText2 = true;
  // Kayıt işlemi sırasında yüklenme durumunu gösterir.
  bool _isLoading = false;
  // Hata mesajlarını göstermek için kullanılır.
  String? _errorMessage;

  @override
  void dispose() {
    // Widget kaldırıldığında kaynakları serbest bırakır (hafıza sızıntılarını önler).
    _usernameController.dispose(); // EKLENDİ
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Asenkron kayıt olma fonksiyonu.
  Future<void> _register() async {
    // Yüklenme durumunu başlat ve hata mesajını temizle.
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Temel istemci tarafı doğrulaması.
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Şifreler eşleşmiyor';
        _isLoading = false;
      });
      return;
    }
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Kullanıcı adı, e-posta ve şifre alanları boş bırakılamaz.';
        _isLoading = false;
      });
      return;
    }

    final String username = _usernameController.text;
    final String email = _emailController.text;
    final String password = _passwordController.text;

    try {
      // ApiService kullanarak kayıt isteği gönder
      final apiService = ApiService();
      final response = await apiService.post(
        'signup', // Endpoint
        {
          'username': username,
          'email': email,
          'password': password,
        },
      );

      // ApiService zaten başarılı yanıtları işliyor ve hataları fırlatıyor.
      // Bu noktaya geldiysek, istek başarılı demektir.
      print('Kayıt başarılı!');

      // Widget hala ekranda mı kontrolü.
      if (!mounted) return;

      // Kayıt başarılı, kullanıcıyı giriş sayfasına yönlendir
      Navigator.pushReplacementNamed(context, '/login'); // Giriş sayfasına yönlendir

      // Başarı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt başarılı! Lütfen giriş yapın.'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      // ApiService'dan gelen hataları yakala (kayıt hatası)
      print('!!! Kayıt Sırasında Hata Oluştu: $e');
      if (!mounted) return;
      setState(() {
        // Hata mesajını daha kullanıcı dostu hale getirebilirsiniz
        _errorMessage = 'Kayıt başarısız: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  // Widget'ın arayüzünü oluşturan metot.
  Widget build(BuildContext context) {
    // Temadan renkleri alalım
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Temel sayfa yapısı.
    return Scaffold(
      backgroundColor: colorScheme.surface, // Arka plan rengi tema yüzey rengi.
      // Üst uygulama çubuğu.
      appBar: AppBar(
        title: Text('Hesap Oluştur', style: TextStyle(color: colorScheme.onSurface, fontSize: 18)), // Sayfa başlığı.
        backgroundColor: colorScheme.surface, // Arka plan tema yüzey rengi.
        elevation: 0, // Gölge yok.
        iconTheme: IconThemeData(color: colorScheme.onSurface), // Geri butonu rengi tema yüzey rengi üzerinde okunabilir renk.
      ),
      // İçeriğin kaydırılabilir olmasını sağlar (klavye açıldığında taşmayı önler).
      body: SingleChildScrollView(
        // Kenarlardan boşluk bırakır.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          // Öğeleri dikey olarak dizer.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Öğeleri yatayda ortala.
            children: [
              // Google ile Kaydol Butonu (Fonksiyonellik eklenmedi)
              // ... (Google butonu kodu aynı kalabilir) ...

              // Ayırıcı Çizgi ve "veya" Metni
              // ... (Ayırıcı kodu aynı kalabilir) ...

               // Kullanıcı Adı Giriş Alanı --- EKLENDİ ---
               TextField(
                 controller: _usernameController, // Metin denetleyicisi.
                 keyboardType: TextInputType.text, // Normal metin klavyesi.
                 decoration: InputDecoration(
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                   hintText: 'Kullanıcı Adı', // İpucu metni.
                   border: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   enabledBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   focusedBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: colorScheme.primary),
                   ),
                 ),
               ),
               const SizedBox(height: 16), // Alanlar arasına boşluk.

              // E-posta Giriş Alanı
              TextField(
                controller: _emailController, // Metin denetleyicisi.
                keyboardType: TextInputType.emailAddress, // E-posta için uygun klavye.
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // İç boşluk.
                  hintText: 'E-posta adresi', // İpucu metni.
                  border: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                  ),
                   enabledBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   focusedBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: colorScheme.primary), // Odaklanınca tema rengi.
                   ),
                ),
              ),
              const SizedBox(height: 16), // Alanlar arasına boşluk.


              // Şifre Giriş Alanı
              TextField(
                controller: _passwordController, // Metin denetleyicisi.
                obscureText: _obscureText1, // Metni gizle (şifre).
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // İç boşluk.
                  hintText: 'Şifre', // İpucu metni.
                  border: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   enabledBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   focusedBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: colorScheme.primary),
                   ),
                  suffixIcon: IconButton(
                    icon: Icon(
                       _obscureText1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                       color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText1 = !_obscureText1;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16), // Alanlar arasına boşluk.

              // Şifre Onaylama Giriş Alanı
              TextField(
                controller: _confirmPasswordController, // Metin denetleyicisi.
                obscureText: _obscureText2, // Metni gizle (şifre).
                 decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // İç boşluk.
                  hintText: 'Şifreyi Onayla', // İpucu metni.
                  border: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   enabledBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   focusedBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: colorScheme.primary),
                   ),
                  suffixIcon: IconButton(
                    icon: Icon(
                       _obscureText2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                       color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText2 = !_obscureText2;
                      });
                    },
                  ),
                ),
              ),

              // Hata Mesajı Gösterimi
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0), // Üstten boşluk.
                  child: Text(
                    _errorMessage!, // Hata mesajını göster.
                    style: TextStyle(color: colorScheme.error, fontSize: 14), // Hata rengi.
                    textAlign: TextAlign.center, // Metni ortala.
                  ),
                ),
              const SizedBox(height: 24), // Hata mesajı ile buton arasına boşluk.

              // Kaydol Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _register, // Yükleniyorsa butonu devre dışı bırak
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, // Buton arka plan rengi tema birincil rengi
                  foregroundColor: colorScheme.onPrimary, // Buton yazı rengi tema birincil rengi üzerinde okunabilir renk
                  padding: const EdgeInsets.symmetric(vertical: 16), // İç boşluk
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // Köşe yuvarlaklığı
                  ),
                  minimumSize: const Size(double.infinity, 50), // Butonun minimum boyutu (genişlik sonsuz, yükseklik 50)
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white) // Yükleniyorsa yüklenme göstergesi
                    : const Text(
                        'Kayıt Ol', // Buton metni
                        style: TextStyle(fontSize: 18), // Yazı boyutu
                      ),
              ),
              const SizedBox(height: 24), // Kaydol butonu ile alttaki link arasına boşluk.

              // Giriş Yapma Bağlantısı
              // ... (Giriş yap bağlantısı kodu aynı kalabilir) ...
            ],
          ),
        ),
      ),
    );
  }
}
