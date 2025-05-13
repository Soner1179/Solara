// lib/constants/api_constants.dart
import 'package:flutter/foundation.dart' show kIsWeb; // Platformun web olup olmadığını kontrol etmek için.

// API uç noktalarının (endpoints) yollarını içeren sınıf.
class ApiEndpoints {
  // Backend API'si (app.py) için temel URL'yi tanımla.
  // Web/Masaüstü için 127.0.0.1, Android emülatörü için 10.0.2.2 kullan.
  // Fiziksel cihazlar için bilgisayarın yerel IP adresi kullanılmalıdır.
  // (iOS Simülatörü genellikle doğrudan 'localhost' veya makinenin IP'sini kullanabilir)
  static const String baseUrl = kIsWeb
      ? 'http://127.0.0.1:5000' // Eğer uygulama web üzerinde çalışıyorsa bu adresi kullan.
      : 'http://10.0.2.2:5000'; // Android emülatörü için bu adresi kullan.

  // Giriş yapma (login) işlemi için API yolu.
  static const String login = '/api/login';
  // Kayıt olma (signup) işlemi için API yolu.
  static const String signup = '/api/signup';
  // Profil verilerini çekmek için temel API yolu (sonuna kullanıcı adı eklenebilir).
  static const String profileBase = '/api/profile';
  // Gönderileri (posts) çekmek için API yolu.
  static const String posts = '/api/posts';
  // Şifremi unuttum (forgot password) işlemi için API yolu (örnek).
  static const String forgotPassword = '/api/forgot-password';
  // Gerektikçe daha fazla API uç noktası buraya eklenebilir.
}

// Varsayılan avatar resmi için asset yolu.
const String defaultAvatar = 'assets/images/default_avatar.png';
