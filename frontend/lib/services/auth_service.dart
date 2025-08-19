import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey = 'auth_token';

  // Already existed in your project:
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // NEW: save token
  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    var cleaned = token.trim();
    cleaned = cleaned.replaceFirst(
      RegExp(r'^token\s+', caseSensitive: false), // strip leading "Token "
      '',
    );
    await prefs.setString(_tokenKey, cleaned);
  }

  // NEW: clear token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
