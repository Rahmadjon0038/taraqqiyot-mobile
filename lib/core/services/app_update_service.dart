import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/api_config.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.updateAvailable,
    required this.forceUpdate,
    required this.message,
    required this.storeUrl,
    required this.latestVersionName,
  });

  final bool updateAvailable;
  final bool forceUpdate;
  final String message;
  final String storeUrl;
  final String latestVersionName;

  static const none = AppUpdateInfo(
    updateAvailable: false,
    forceUpdate: false,
    message: '',
    storeUrl: '',
    latestVersionName: '',
  );

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      updateAvailable: json['update_available'] == true,
      forceUpdate: json['force_update'] == true,
      message: json['message']?.toString() ?? '',
      storeUrl: json['store_url']?.toString() ?? '',
      latestVersionName: json['latest_version_name']?.toString() ?? '',
    );
  }
}

/// Ilova ochilganda backenddan "eng so'nggi versiya" ma'lumotini so'raydi.
/// Play Market/App Store'ning o'zi bu haqda ilova ichida hech narsa
/// aytmaydi — shuning uchun buni backend orqali boshqarilaverib turamiz.
class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 8);

  Future<AppUpdateInfo> checkForUpdate() async {
    final platform = _platformName();
    if (platform == null) return AppUpdateInfo.none;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildNumber = int.tryParse(packageInfo.buildNumber);
      if (buildNumber == null || buildNumber <= 0) return AppUpdateInfo.none;

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/app/version-check').replace(
        queryParameters: {
          'platform': platform,
          'build_number': buildNumber.toString(),
        },
      );

      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppUpdateInfo.none;
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is! Map) return AppUpdateInfo.none;

      return AppUpdateInfo.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      // Versiya tekshiruvi ilova ishga tushishiga xalaqit bermasligi kerak
      return AppUpdateInfo.none;
    }
  }

  String? _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null;
  }

  void dispose() {
    _client.close();
  }
}
