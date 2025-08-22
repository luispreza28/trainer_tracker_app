import 'package:shared_preferences/shared_preferences.dart';

class TzService {
  static const _key = 'user_tz';

  Future<String?> getTz() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> setTz(String tz) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, tz);
  }
}
