import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Ayarı kaydetmek için

class ThemeService with ChangeNotifier {
  final String key = "theme_mode"; // SharedPreferences için anahtar
  ThemeMode _themeMode = ThemeMode.system; // Başlangıç değeri
  SharedPreferences? _prefs; // SharedPreferences örneği

  ThemeMode get themeMode => _themeMode;

  ThemeService() {
    _loadThemeMode(); // Servis oluşturulduğunda kayıtlı temayı yükle
  }

  // Kayıtlı tema modunu yükle
  Future<void> _loadThemeMode() async {
    _prefs = await SharedPreferences.getInstance();
    final int? savedThemeIndex = _prefs?.getInt(key);
    if (savedThemeIndex != null) {
      _themeMode = ThemeMode.values[savedThemeIndex];
    }
    // Dinleyicilere haber vermeye gerek yok, ilk yüklemede zaten build olacak
    // notifyListeners(); // Burası gerekli değil
    print("Loaded ThemeMode: $_themeMode");
  }

  // Tema modunu kaydet
  Future<void> _saveThemeMode(ThemeMode mode) async {
    await _prefs?.setInt(key, mode.index);
     print("Saved ThemeMode: $mode");
  }

  // Temayı değiştiren public metot
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return; // Zaten aynıysa bir şey yapma
    _themeMode = mode;
    _saveThemeMode(mode); // Yeni seçimi kaydet
    notifyListeners(); // Değişikliği dinleyicilere bildir
  }

  // Toggle metodu (isteğe bağlı, sadece light/dark arası geçiş için)
  void toggleTheme() {
    // Şu anki duruma göre tersini seç (System ise Light'a geç gibi bir mantık da kurulabilir)
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newMode);
  }
}