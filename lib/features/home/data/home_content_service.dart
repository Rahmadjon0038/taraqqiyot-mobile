import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/config/api_config.dart';
import '../../auth/models/auth_session.dart';
import '../presentation/widgets/home_news_carousel.dart';
import '../presentation/widgets/home_stories.dart';

/// Bosh sahifa kontenti — storislar va yangiliklar (admin paneldan boshqariladi)
class HomeContent {
  const HomeContent({required this.stories, required this.news});

  final List<StoryData> stories;
  final List<HomeNewsItem> news;
}

class HomeContentService {
  HomeContentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 15);

  /// Storis halqalari uchun gradient ranglar to'plami (indeks bo'yicha aylanadi)
  static const List<(Color, Color)> _accentPalette = [
    (Color(0xFF38E0A3), Color(0xFF1FB6FF)),
    (Color(0xFF58D68D), Color(0xFF2E86DE)),
    (Color(0xFF7F7CFF), Color(0xFF3CC8A8)),
    (Color(0xFFFFC857), Color(0xFFFF7A59)),
    (Color(0xFF4FD1C5), Color(0xFF22C55E)),
    (Color(0xFF8B5CF6), Color(0xFFEC4899)),
  ];

  Map<String, String> _headers(AuthSession session) => {
    'Authorization': 'Bearer ${session.accessToken}',
  };

  List<dynamic> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Kontent yuklanmadi (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map ? decoded['data'] : decoded;
    return data is List ? data : const [];
  }

  /// Video URL localhost bilan kelsa API bazasiga almashtiramiz
  /// (server PUBLIC_BASE_URL o'rnatilmagan holat uchun himoya)
  static String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      if (trimmed.contains('localhost') || trimmed.contains('127.0.0.1')) {
        final uri = Uri.tryParse(trimmed);
        if (uri != null) return '${ApiConfig.baseUrl}${uri.path}';
      }
      return trimmed;
    }
    return trimmed.startsWith('/')
        ? '${ApiConfig.baseUrl}$trimmed'
        : '${ApiConfig.baseUrl}/$trimmed';
  }

  Future<List<StoryData>> fetchStories(AuthSession session) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/content/stories'),
          headers: _headers(session),
        )
        .timeout(_timeout);

    final items = _decodeList(response);
    final stories = <StoryData>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) continue;
      final videoUrl = _normalizeUrl(
        item['video_url']?.toString() ?? item['video_path']?.toString() ?? '',
      );
      if (videoUrl.isEmpty) continue;
      final accent = _accentPalette[i % _accentPalette.length];
      stories.add(
        StoryData(
          videoUrl: videoUrl,
          accentStart: accent.$1,
          accentEnd: accent.$2,
        ),
      );
    }
    return stories;
  }

  Future<List<HomeNewsItem>> fetchNews(AuthSession session) async {
    final response = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/content/news'),
          headers: _headers(session),
        )
        .timeout(_timeout);

    return _decodeList(
      response,
    ).whereType<Map>().map((item) => HomeNewsItem.fromJson(item)).toList();
  }

  /// Ikkalasini birga yuklaydi — biri xato bersa ham ikkinchisi ko'rinaveradi
  Future<HomeContent> fetchAll(AuthSession session) async {
    final results = await Future.wait([
      fetchStories(session).catchError((_) => const <StoryData>[]),
      fetchNews(session).catchError((_) => const <HomeNewsItem>[]),
    ]);
    return HomeContent(
      stories: results[0] as List<StoryData>,
      news: results[1] as List<HomeNewsItem>,
    );
  }

  /// Yangi storis yuklash (super admin) — telefondan tanlangan video fayl
  Future<void> uploadStory(
    AuthSession session, {
    required String filePath,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/content/stories'),
    );
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    request.files.add(
      await http.MultipartFile.fromPath(
        'video',
        filePath,
        filename: fileName,
        contentType: MediaType('video', 'mp4'),
      ),
    );
    request.fields['title'] = '';

    final streamed = await request.send().timeout(
      const Duration(minutes: 5),
    );
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Storis yuklanmadi';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  void dispose() {
    _client.close();
  }
}
