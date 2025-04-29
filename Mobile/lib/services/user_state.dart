import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserState with ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  static const String _userKey = 'currentUser';

  Map<String, dynamic>? get currentUser => _currentUser;

  Future<void> setCurrentUser(Map<String, dynamic>? user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      await prefs.setString(_userKey, json.encode(user));
    } else {
      await prefs.remove(_userKey);
    }
    notifyListeners();
  }

  bool get isLoggedIn => _currentUser != null;

  Future<void> loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _currentUser = json.decode(userJson) as Map<String, dynamic>;
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    notifyListeners();
  }
}
