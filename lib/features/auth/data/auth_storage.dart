import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

class AuthStorage {
  static const String _sessionKey = 'taraqqiyot_auth_session';

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, session.toEncodedJson());
  }

  Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedSession = prefs.getString(_sessionKey);
    if (encodedSession == null || encodedSession.isEmpty) {
      return null;
    }

    try {
      return AuthSession.fromEncodedJson(encodedSession);
    } catch (error) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
