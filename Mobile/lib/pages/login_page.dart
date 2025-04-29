// lib/pages/login_page.dart
import 'dart:convert'; // JSON dönüşümleri için gerekli.
import 'dart:async';  // TimeoutException için EKLENDİ

import 'package:flutter/material.dart'; // Flutter'ın Material Design widget'ları.
import 'package:http/http.dart' as http; // HTTP istekleri yapmak için.
import 'package:provider/provider.dart'; // Provider importu <--- EKLENDİ
import 'package:solara/services/api_service.dart'; // ApiService importu
import 'package:solara/services/user_state.dart'; // UserState importu <--- EKLENDİ

// Proje adınız 'solara' varsayılarak import edildi.
// Farklıysa 'solara' kısmını kendi proje adınızla değiştirin.
// !!! baseUrl'i kontrol edin: http://<BILGISAYAR_IP>:5000 olmalı !!!
import 'package:solara/constants/api_constants.dart';
import 'package:solara/pages/home_page.dart'; // Ana sayfa.
import 'package:solara/pages/register_page.dart'; // Kayıt olma sayfası.

// LoginPage: Stateful bir widget, yani durumu değişebilir.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key}); // Kurucu metot.

  @override
  // State nesnesini oluşturur.
  State<LoginPage> createState() => _LoginPageState();
}

// _LoginPageState: LoginPage'in durumunu yöneten sınıf.
class _LoginPageState extends State<LoginPage> {
  // E-posta veya kullanıcı adı için metin giriş denetleyicisi.
  final _emailController = TextEditingController(); // Orijinal isim kullanıldı
  // Şifre için metin giriş denetleyicisi.
  final _passwordController = TextEditingController();
  // Şifrenin gizli olup olmadığını kontrol eden bayrak.
  bool _obscureText = true;
  // API isteği sırasında yüklenme durumunu gösteren bayrak.
  bool _isLoading = false;
  // API'den gelen veya işlem sırasında oluşan hata mesajını tutar.
  String? _errorMessage;

  @override
  void dispose() {
    // Widget ağaçtan kaldırıldığında denetleyicileri temizle.
    // Bu, hafıza sızıntılarını önler.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- SADECE BU FONKSİYON GÜNCELLENDİ ---
  // Asenkron giriş yapma fonksiyonu.
  Future<void> _login() async {
    // Arayüzü güncelleyerek yüklenme durumunu başlat ve hata mesajını temizle.
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Metin alanlarından kullanıcı adı/e-posta ve şifreyi al, boşlukları temizle.
    final String usernameOrEmail = _emailController.text.trim();
    final String password = _passwordController.text;

    // Basit istemci tarafı doğrulama
    if (usernameOrEmail.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen tüm alanları doldurun.';
        _isLoading = false;
      });
      return;
    }

    try {
      // ApiService kullanarak giriş isteği gönder
      final apiService = ApiService();
      final response = await apiService.post(
        'login', // Endpoint
        {
          'username_or_email': usernameOrEmail,
          'password': password,
        },
      );

      // ApiService zaten başarılı yanıtları işliyor ve hataları fırlatıyor.
      // Bu noktaya geldiysek, istek başarılı demektir.
      print('Giriş başarılı!');

      // Yanıttaki kullanıcı verilerini al
      final user = response['user'];
      final token = response['token'];

      print('Kullanıcı Verileri: $user');
      print('Token: $token');

      // TODO: Token ve kullanıcı verilerini güvenli bir şekilde sakla.

      // Widget hala ekranda mı kontrolü (asenkron işlem sonrası için önemli).
      if (!mounted) return;

      // UserState'i güncelle
      final userState = Provider.of<UserState>(context, listen: false);
      await userState.setCurrentUser(user); // Use await because setCurrentUser is now async

      // Kullanıcıyı ana sayfaya yönlendir ve geri dönememesini sağla.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );

    } catch (e) {
      // ApiService'dan gelen hataları yakala
      print('!!! Giriş Sırasında Hata Oluştu: $e');
      // Widget hala ekranda mı kontrolü.
      if (!mounted) return;
      // Arayüzü güncelleyerek hata mesajını göster.
      setState(() {
        // Hata mesajını daha kullanıcı dostu hale getirebilirsiniz
        _errorMessage = 'Giriş başarısız: ${e.toString()}';
      });
    } finally {
      // İstek başarılı da olsa, başarısız da olsa veya hata da olsa çalışacak blok.
      // Widget hala ekranda mı kontrolü.
      if (mounted) {
        // Yüklenme durumunu bitir.
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  // Widget'ın arayüzünü oluşturan metot.
  // !!! BU KISIM SİZİN GÖNDERDİĞİNİZ ORİJİNAL KOD İLE AYNI !!!
  Widget build(BuildContext context) {
    // Temadan renkleri alalım
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Temel Material Design sayfa yapısı.
    return Scaffold(
      backgroundColor: colorScheme.surface, // Arka plan rengi tema yüzey rengi.
      // İçeriğin klavye açıldığında vb. taşmasını önlemek için kaydırılabilir alan.
      body: SingleChildScrollView(
        // Kenarlardan boşluk bırakır.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          // Elementleri dikey olarak dizer.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // İçeriği yatayda ortala.
            children: [
              // Logo ve Uygulama Adı
             Row(
                mainAxisAlignment: MainAxisAlignment.center, // İçeriği yatayda ortala.
                children: [
                  // .png dosyası için Image.asset kullanın
                  Image.asset(
                    'assets/images/sun-shape.png', // .png dosyasının yolu
                    width: 30,
                    height: 30,
                    // İsteğe bağlı: Resim yüklenemezse hata ikonu göster
                    errorBuilder: (context, error, stackTrace) {
                      print('Logo yüklenemedi: $error'); // Hatayı konsola yazdır
                      return Icon(Icons.error, color: colorScheme.error, size: 30);
                    },
                  ),
                  // --- DEĞİŞİKLİK SONU ---
                  const SizedBox(width: 10), // Araya 10 piksel boşluk koy.
                  // Uygulama adı metni.
                  Text(
                    'Solara',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface, // Tema yüzey rengi üzerinde okunabilir renk.
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // Logo ile sonraki eleman arasına boşluk (kodunuzda 20 idi).

              // Google ile Oturum Açma Butonu
              Container(
                width: double.infinity, // Genişliği tüm satıra yay.
                height: 50, // Yükseklik 50 piksel.
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor), // Kenarlık rengi tema bölücü rengi.
                  borderRadius: BorderRadius.circular(8) // Köşeleri yuvarlat.
                ),
                // İkonlu Metin Butonu (Google).
                child: TextButton.icon(
                  icon: Image.asset( // Google logosu (.png olduğu için Image.asset)
                    'assets/images/google-logo.png', // .png dosyasının yolu
                    width: 24,
                    height: 24,
                    // İsteğe bağlı: Resim yüklenemezse hata göster
                    errorBuilder: (context, error, stackTrace) {
                      print('Google logo yüklenemedi: $error');
                      return Icon(Icons.broken_image, size: 24, color: colorScheme.onSurface.withOpacity(0.6)); // Placeholder ikon
                    },
                  ),
                  // --- DEĞİŞİKLİK SONU ---
                  label: Text( // Buton metni.
                    'Google ile oturum açın',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface, // Tema yüzey rengi üzerinde okunabilir renk.
                    ),
                  ),
                  // Butona tıklandığında çalışacak fonksiyon.
                  onPressed: () {
                    print('Giriş Sayfası: Google Girişi Tıklandı (TODO)'); // Konsola mesaj yaz.
                    // Kullanıcıya geçici bilgi mesajı göster.
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Google ile giriş henüz aktif değil.')),
                     );
                  },
                  // Buton stili.
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurface, // Metin rengi tema yüzey rengi üzerinde okunabilir renk.
                    shape: RoundedRectangleBorder( // Şekli (köşeleri yuvarlat).
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // Ayırıcı Çizgi ve "veya" Metni
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24), // Üstten ve alttan boşluk.
                child: Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, color: theme.dividerColor)), // Sol çizgi.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10), // "veya" etrafında boşluk.
                      child: Text('veya', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))), // "veya" metni.
                    ),
                    Expanded(child: Divider(thickness: 1, color: theme.dividerColor)), // Sağ çizgi.
                  ],
                ),
              ),

              // E-posta/Kullanıcı Adı Giriş Alanı
              TextField(
                controller: _emailController, // Metin denetleyicisi.
                keyboardType: TextInputType.emailAddress, // Klavye türü (e-posta önerileri).
                decoration: InputDecoration( // Giriş alanı dekorasyonu/stili.
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // İç boşluk.
                  hintText: 'E-posta veya kullanıcı adı', // İpucu metni.
                  border: OutlineInputBorder( // Varsayılan kenarlık.
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                  ),
                   enabledBorder: OutlineInputBorder( // Aktif (odaklanılmamış) kenarlık.
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   focusedBorder: OutlineInputBorder( // Odaklanılmış kenarlık.
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: colorScheme.primary), // Ana tema rengi.
                   ),
                ),
              ),
              const SizedBox(height: 16), // E-posta ve şifre alanı arasına boşluk.

              // Şifre Giriş Alanı
              TextField(
                controller: _passwordController, // Metin denetleyicisi.
                obscureText: _obscureText, // Metni gizle (şifre).
                decoration: InputDecoration( // Giriş alanı dekorasyonu/stili.
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // İç boşluk.
                  hintText: 'Şifre', // İpucu metni.
                  border: OutlineInputBorder( // Varsayılan kenarlık.
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   enabledBorder: OutlineInputBorder( // Aktif kenarlık.
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: theme.dividerColor),
                   ),
                   focusedBorder: OutlineInputBorder( // Odaklanılmış kenarlık.
                     borderRadius: BorderRadius.circular(8),
                     borderSide: BorderSide(color: colorScheme.primary),
                   ),
                   // Alanın sonuna ikon ekler (şifre görünürlüğü için).
                  suffixIcon: IconButton(
                    icon: Icon( // Duruma göre görünür/gizli ikonu.
                      _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: colorScheme.onSurface.withOpacity(0.6), // İkon rengi tema yüzey rengi üzerinde hafif soluk.
                    ),
                    // İkona tıklandığında şifre görünürlüğünü değiştir.
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Bayrağı tersine çevir.
                      });
                    },
                  ),
                ),
              ),

              // Hata Mesajı Gösterimi
              // Eğer _errorMessage null değilse (yani bir hata varsa) bu alanı göster.
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0), // Üstten boşluk.
                  child: Text(
                    _errorMessage!, // Hata mesajını göster.
                    style: TextStyle(color: colorScheme.error, fontSize: 14), // Hata rengi.
                    textAlign: TextAlign.center, // Ortalanmış metin.
                  ),
                ),
              const SizedBox(height: 24), // Şifre/Hata ile Giriş Butonu arasına boşluk.

              // Giriş Yap Butonu
              SizedBox(
                width: double.infinity, // Genişliği tüm satıra yay.
                height: 50, // Yükseklik 50 piksel.
                child: ElevatedButton(
                  // Eğer yükleniyorsa (_isLoading true ise) butonu pasif yap, değilse _login fonksiyonunu çağır.
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom( // Buton stili.
                    backgroundColor: colorScheme.primary, // Arka plan rengi tema ana rengi.
                    foregroundColor: colorScheme.onPrimary, // Metin/ikon rengi tema ana rengi üzerinde okunabilir renk.
                    shape: RoundedRectangleBorder( // Şekli (köşeleri yuvarlat).
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2, // Hafif gölge efekti.
                  ),
                  // Buton içeriği: Yükleniyorsa dönen ikon, değilse "Giriş Yap" metni.
                  child: _isLoading
                      ? SizedBox( // Yükleniyor animasyonu (CircularProgressIndicator).
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: colorScheme.onPrimary, // Animasyon rengi tema ana rengi üzerinde okunabilir renk.
                          ),
                        )
                      : const Text( // Normal buton metni.
                          'Giriş Yap',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              // Şifremi Unuttum Bağlantısı
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16), // Üstten ve alttan boşluk.
                child: TextButton(
                  // Tıklandığında çalışacak fonksiyon.
                  onPressed: () {
                    print('Giriş Sayfası: Şifremi Unuttum Tıklandı (TODO)'); // Konsola mesaj.
                    // Kullanıcıya geçici bilgi mesajı göster.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şifremi unuttum özelliği yakında eklenecek.')),
                    );
                  },
                  // Bağlantı metni.
                  child: Text(
                    'Şifremi unuttum',
                    style: TextStyle(
                      color: colorScheme.primary, // Ana tema rengi.
                      fontWeight: FontWeight.w500, // Yazı tipi kalınlığı.
                    ),
                  ),
                ),
              ),

              // Kayıt Olma Bağlantısı
              Row(
                mainAxisAlignment: MainAxisAlignment.center, // İçeriği yatayda ortala.
                children: [
                  // Açıklama metni.
                  Text(
                    'Henüz bir hesabın yok mu? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.6), // Hafif soluk renk.
                    ),
                  ),
                  // Kaydol metin butonu.
                  TextButton(
                    // Tıklandığında Kayıt Olma sayfasına yönlendir.
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    // Buton stilini ayarla (gereksiz boşlukları kaldır).
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, // İç boşluk yok.
                      minimumSize: Size.zero, // Minimum boyut yok.
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Tıklama alanını küçült.
                      foregroundColor: colorScheme.primary, // Metin rengi tema rengi.
                    ),
                    // Kaydol metni.
                    child: const Text(
                      'Kaydol',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, // Kalın yazı.
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
