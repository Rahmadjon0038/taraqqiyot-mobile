import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthService {
  const AuthService();

  static const Duration _timeout = Duration(seconds: 8);

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('/api/users/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username.trim(), 'password': password}),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Login muvaffaqiyatsiz',
        statusCode: response.statusCode,
      );
    }

    final userPayload = Map<String, dynamic>.from(
      payload['user'] as Map? ?? const {},
    );

    return AuthSession(
      accessToken: payload['accessToken']?.toString() ?? '',
      refreshToken: payload['refreshToken']?.toString() ?? '',
      user: AuthUser.fromJson(userPayload),
    );
  }

  Future<AuthUser> fetchProfile(String accessToken) async {
    final response = await http
        .get(
          _uri('/api/users/profile'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Profil yuklanmadi',
        statusCode: response.statusCode,
      );
    }

    final user = AuthUser.fromJson(payload);
    return user;
  }

  Future<AuthUser> updateProfile(
    String accessToken,
    Map<String, dynamic> payload,
  ) async {
    final response = await http
        .patch(
          _uri('/api/users/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    final decoded = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'Profil yangilanmadi',
        statusCode: response.statusCode,
      );
    }

    final userPayload = decoded['user'];
    if (userPayload is Map) {
      return AuthUser.fromJson(Map<String, dynamic>.from(userPayload));
    }
    return AuthUser.fromJson(decoded);
  }

  Future<String> refreshAccessToken(String refreshToken) async {
    final response = await http
        .post(
          _uri('/api/users/refresh'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(_timeout);

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Access token yangilanmadi',
        statusCode: response.statusCode,
      );
    }

    final accessToken = payload['accessToken']?.toString() ?? '';
    if (accessToken.isEmpty) {
      throw const AuthException('Access token qaytmadi');
    }
    return accessToken;
  }

  static String timeoutMessage(String action) {
    return '$action uchun backend javob bermadi. Server ishga tushganini tekshiring.';
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{'data': decoded};
  }
}
