import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/config/api_config.dart';
import 'avatar_catalog.dart';

class AvatarLibraryService {
  const AvatarLibraryService();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  String _resolveImageUrl(String? imageUrl) {
    final raw = imageUrl?.trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      if (raw.contains('localhost') || raw.contains('127.0.0.1')) {
        final uri = Uri.tryParse(raw);
        if (uri != null) {
          return '${ApiConfig.baseUrl}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
        }
      }
      return raw;
    }
    return '${ApiConfig.baseUrl}$raw';
  }

  MediaType _guessContentType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      case 'heif':
        return MediaType('image', 'heif');
      case 'bmp':
        return MediaType('image', 'bmp');
      case 'tif':
      case 'tiff':
        return MediaType('image', 'tiff');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Future<List<AvatarOption>> fetchPublishedAvatars(String accessToken) async {
    final response = await http
        .get(
          _uri('/api/profile-avatars'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 10));

    final payload = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Avatarlar ro\'yxati yuklanmadi',
      );
    }

    final avatars = payload['avatars'];
    if (avatars is! List) {
      return const [];
    }

    final remote = avatars
        .whereType<Map>()
        .map((item) {
          final json = Map<String, dynamic>.from(item);
          return AvatarOption(
            key: json['avatar_key']?.toString() ?? '',
            label: 'Avatar',
            icon: Icons.person_rounded,
            colors: const [Color(0xFFA70E07), Color(0xFFCB3A31)],
            imageUrl: _resolveImageUrl(json['image_url']?.toString()),
          );
        })
        .where((option) => option.key.isNotEmpty)
        .toList();

    AvatarRegistry.instance.registerAll(remote);

    if (remote.isEmpty) {
      return const [defaultAvatarOption];
    }

    return remote;
  }

  Future<AvatarOption> uploadAvatar({
    required String accessToken,
    required String filePath,
    String? name,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/profile-avatars'));
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields['is_active'] = 'true';
    final trimmedName = name?.trim() ?? '';
    if (trimmedName.isNotEmpty) {
      request.fields['name'] = trimmedName;
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        filePath,
        contentType: _guessContentType(filePath),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final payload = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Avatar yuklashda xatolik',
      );
    }

    final avatar = payload['avatar'];
    if (avatar is Map) {
      final json = Map<String, dynamic>.from(avatar);
      final created = AvatarOption(
        key: json['avatar_key']?.toString() ?? '',
        label: 'Avatar',
        icon: Icons.person_rounded,
        colors: const [Color(0xFFA70E07), Color(0xFFCB3A31)],
        imageUrl: _resolveImageUrl(json['image_url']?.toString()),
      );
      AvatarRegistry.instance.register(created);
      return created;
    }

    final fallback = AvatarOption(
      key: '',
      label: 'Avatar',
      icon: Icons.person_rounded,
      colors: const [Color(0xFFA70E07), Color(0xFFCB3A31)],
    );
    AvatarRegistry.instance.register(fallback);
    return fallback;
  }

  Future<List<AvatarOption>> pickImageAndUpload({
    required String accessToken,
    required String name,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );

    final path = result?.files.single.path;
    if (path == null || path.isEmpty) {
      return const [];
    }

    final avatar = await uploadAvatar(
      accessToken: accessToken,
      filePath: path,
      name: name,
    );
    return [avatar];
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
