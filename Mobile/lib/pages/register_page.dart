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

// Kayıt aşamalarını tanımlayan enum.
enum RegisterStage { enterEmail, enterCode }

// RegisterPage: Kullanıcı kayıt ekranını temsil eden Stateful widget.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key}); // Kurucu metot.

  @override
  // State nesnesini oluşturur.
  State<RegisterPage> createState() => _RegisterPageState();
}

// _RegisterPageState: RegisterPage'in durumunu yöneten sınıf.
class _RegisterPageState extends State<RegisterPage> {
  // Mevcut kayıt aşamasını takip eder.
  RegisterStage _currentStage = RegisterStage.enterEmail;

  // Kullanıcı adı giriş alanı için denetleyici.
  final _usernameController = TextEditingController();
  // E-posta giriş alanı için denetleyici.
  final _emailController = TextEditingController();
  // Şifre giriş alanı için denetleyici.
  final _passwordController = TextEditingController();
  // Şifre onaylama alanı için denetleyici.
  final _confirmPasswordController = TextEditingController();
  // Doğrulama kodu giriş alanı için denetleyici.
  final _verificationCodeController = TextEditingController();


  // İlk şifre alanının görünürlüğünü kontrol eder.
  bool _obscureText1 = true;
  // İkinci şifre alanının görünürlüğünü kontrol eder.
  bool _obscureText2 = true;
  // Kayıt işlemi sırasında yüklenme durumunu gösterir.
  bool _isLoading = false;
  // Hata mesajlarını göstermek için kullanılır.
  String? _errorMessage;
  // Başarı mesajlarını göstermek için kullanılır (kod gönderildi gibi).
  String? _successMessage;


  @override
  void dispose() {
    // Widget kaldırıldığında kaynakları serbest bırakır (hafıza sızıntılarını önler).
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  // E-posta doğrulama kodu gönderme fonksiyonu.
  Future<void> _sendVerificationCode() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen e-posta adresinizi girin.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final String email = _emailController.text;

    try {
      final apiService = ApiService();
      final response = await apiService.post(
        'send_verification_code', // Yeni endpoint
        {'email': email},
      );

      // ApiService başarılı yanıtları işler.
      // Bu noktaya geldiysek, istek başarılı demektir.
      print('Doğrulama kodu gönderme isteği başarılı!');

      if (!mounted) return;
      setState(() {
        _successMessage = response['message'] ?? 'Doğrulama kodu e-postanıza gönderildi.';
        _currentStage = RegisterStage.enterCode; // Bir sonraki aşamaya geç.
        _errorMessage = null;
      });
    } catch (e) {
      print('!!! Doğrulama Kodu Gönderme Sırasında Hata Oluştu: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Kod gönderme başarısız: ${e.toString()}';
        _successMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // Asenkron kayıt olma fonksiyonu (doğrulama kodu ile).
  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null; // Önceki başarı mesajını temizle
    });

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Şifreler eşleşmiyor';
        _isLoading = false;
      });
      return;
    }
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty || // E-posta hala gerekli
        _passwordController.text.isEmpty ||
        _verificationCodeController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Tüm alanlar (kullanıcı adı, e-posta, şifre, doğrulama kodu) boş bırakılamaz.';
        _isLoading = false;
      });
      return;
    }

    final String username = _usernameController.text;
    final String email = _emailController.text; // E-posta ilk aşamadan alınır.
    final String password = _passwordController.text;
    final String verificationCode = _verificationCodeController.text;

    try {
      final apiService = ApiService();
      final response = await apiService.post(
        'signup', // Endpoint
        {
          'username': username,
          'email': email,
          'password': password,
          'verification_code': verificationCode, // Doğrulama kodunu ekle
        },
      );

      print('Kayıt başarılı!');
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/login');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt başarılı ve e-posta doğrulandı! Lütfen giriş yapın.'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('!!! Kayıt Sırasında Hata Oluştu: $e');
      if (!mounted) return;
      setState(() {
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


  // UI'ı mevcut aşamaya göre oluşturan yardımcı metot.
  List<Widget> _buildFormChildren(ThemeData theme, ColorScheme colorScheme) {
    if (_currentStage == RegisterStage.enterEmail) {
      return [
        // E-posta Giriş Alanı
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: 'E-posta adresi',
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
        const SizedBox(height: 24),
        // Kod Gönderme Butonu
        ElevatedButton(
          onPressed: _isLoading ? null : _sendVerificationCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Doğrulama Kodu Gönder', style: TextStyle(fontSize: 18)),
        ),
      ];
    } else { // RegisterStage.enterCode
      return [
        // Başarı mesajı (kod gönderildi gibi)
        if (_successMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _successMessage!,
              style: TextStyle(color: Colors.green, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        // Doğrulama Kodu Giriş Alanı
        TextField(
          controller: _verificationCodeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: 'Doğrulama Kodu',
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
        const SizedBox(height: 16),
        // Kullanıcı Adı Giriş Alanı
         TextField(
           controller: _usernameController,
           keyboardType: TextInputType.text,
           decoration: InputDecoration(
             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
             hintText: 'Kullanıcı Adı',
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
         const SizedBox(height: 16),
        // Şifre Giriş Alanı
        TextField(
          controller: _passwordController,
          obscureText: _obscureText1,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: 'Şifre',
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
        const SizedBox(height: 16),
        // Şifre Onaylama Giriş Alanı
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureText2,
           decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: 'Şifreyi Onayla',
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
        const SizedBox(height: 24),
        // Kaydol Butonu
        ElevatedButton(
          onPressed: _isLoading ? null : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Kayıt Ol', style: TextStyle(fontSize: 18)),
        ),
      ];
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Dinamik form elemanları
              ..._buildFormChildren(theme, colorScheme),

              // Hata Mesajı Gösterimi
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),

              // Giriş Yapma Bağlantısı
              if (_currentStage == RegisterStage.enterEmail) // Sadece ilk aşamada göster
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Zaten bir hesabın var mı?', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: Text('Giriş Yap', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              if (_currentStage == RegisterStage.enterCode) // İkinci aşamada e-posta değiştirme veya geri dönme
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentStage = RegisterStage.enterEmail;
                      _errorMessage = null;
                      _successMessage = null;
                      _verificationCodeController.clear(); // Kodu temizle
                    });
                  },
                  child: Text('E-posta adresini değiştir veya geri dön', style: TextStyle(color: colorScheme.primary)),
                )
            ],
          ),
        ),
      ),
    );
  }
}
