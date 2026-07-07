import 'dart:io';

class ApiConfig {
  ApiConfig._();

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _localMacBaseUrl = 'https://api.taraqqiyot-teaching-center.uz';
  // static const String _localMacBaseUrl = 'http://192.168.0.64:5001';
  // static const String _androidPhysicalDeviceBaseUrl = 'http://192.168.0.64:5001';
  static const String _androidPhysicalDeviceBaseUrl = 'https://api.taraqqiyot-teaching-center.uz';

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    if (Platform.isAndroid) {
      return _androidPhysicalDeviceBaseUrl;
    }

    if (Platform.isMacOS || Platform.isIOS) {
      return _localMacBaseUrl;
    }

    return 'http://127.0.0.1:5001';
  }
}
