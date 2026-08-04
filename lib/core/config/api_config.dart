class ApiConfig {
  ApiConfig._();

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _productionBaseUrl =
      'https://api.taraqqiyot-teaching-center.uz';

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    return _productionBaseUrl;
  }
}
