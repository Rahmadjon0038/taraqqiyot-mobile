import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../pages/home_news_detail_page.dart';

/// Yangilik elementi — admin paneldan boshqariladi (backend'dan keladi).
class HomeNewsItem {
  const HomeNewsItem({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String tag;
  final String title;
  final String subtitle;

  /// Yangilik sahifasida o'qiladigan to'liq matn
  final String body;

  factory HomeNewsItem.fromJson(Map<dynamic, dynamic> json) {
    String asText(Object? value) {
      final text = value?.toString() ?? '';
      return text == 'null' ? '' : text;
    }

    return HomeNewsItem(
      tag: asText(json['tag']).isEmpty ? 'Yangilik' : asText(json['tag']),
      title: asText(json['title']),
      subtitle: asText(json['subtitle']),
      body: asText(json['body']),
    );
  }
}

/// Bosh sahifadagi yangiliklar karuseli.
/// "Batafsil" tugmasi yangilik sahifasini ochadi.
class HomeNewsCarousel extends StatefulWidget {
  const HomeNewsCarousel({super.key, required this.items});

  final List<HomeNewsItem> items;

  @override
  State<HomeNewsCarousel> createState() => _HomeNewsCarouselState();
}

class _HomeNewsCarouselState extends State<HomeNewsCarousel> {
  PageController? _controller;
  int _currentPage = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      // PageView har sahifani markazlaydi — chetki bo'shliq (1-fraction)*w/2,
      // ichki padding 4px. (w-16)/w fraction bilan chet 8+4 = 12px bo'ladi —
      // sahifadagi boshqa cartlarning chetki masofasi bilan bir xil.
      final width = MediaQuery.of(context).size.width;
      final fraction = width > 48
          ? ((width - 16) / width).clamp(0.5, 1.0)
          : 0.96;
      _controller = PageController(viewportFraction: fraction.toDouble());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Istalgan karta bosilsa bitta "Yangiliklar" sahifasi ochiladi va
  /// aynan bosilgan yangilikka aylantiriladi
  void _openNewsList(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            HomeNewsListPage(items: widget.items, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: ScrollConfiguration(
            // Sichqoncha va trackpad bilan ham sirpantirish ishlashi uchun
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _NewsCard(
                    item: item,
                    onOpen: () => _openNewsList(index),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.items.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _currentPage ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? const Color(0xFFA70E07)
                        : const Color(0xFFC9D0DC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.onOpen});

  final HomeNewsItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF7F1D1D), Color(0xFFA70E07), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -22,
              bottom: -26,
              child: Transform.rotate(
                angle: -0.22,
                child: Icon(
                  Icons.campaign_rounded,
                  size: 128,
                  color: Colors.white.withValues(alpha: 0.13),
                ),
              ),
            ),
            Positioned(
              right: 86,
              top: -16,
              child: Transform.rotate(
                angle: 0.3,
                child: Icon(
                  Icons.newspaper_rounded,
                  size: 62,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              left: -14,
              bottom: -10,
              child: Icon(
                Icons.notifications_active_rounded,
                size: 54,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              // Karta ikki qism: chapda matnlar, o'ng tomon bo'sh qoladi —
              // bezak iconlar bemalol ko'rinadi, matn ustiga chiqmaydi
              child: Row(
                children: [
                  Expanded(flex: 3, child: _NewsCardContent(item: item)),
                  const Expanded(flex: 1, child: SizedBox()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCardContent extends StatelessWidget {
  const _NewsCardContent({required this.item});

  final HomeNewsItem item;

  /// Qisqa tavsif bo'lmasa matnning boshidan parcha ko'rsatamiz
  /// (markdown belgilarini olib tashlab)
  String get _previewText {
    if (item.subtitle.trim().isNotEmpty) return item.subtitle;
    return item.body
        .replaceAll(RegExp(r'[#*_>`]'), '')
        .replaceAll('\n', ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Oq fondagi qizil qo'ng'iroqli teg — rasmdagi dizayn
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.campaign_rounded,
                size: 14,
                color: Color(0xFFA70E07),
              ),
              const SizedBox(width: 5),
              Text(
                item.tag,
                style: const TextStyle(
                  color: Color(0xFFA70E07),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        // Matn "Batafsil" tugmasigacha bo'lgan joyni to'ldiradi,
        // sig'magani ... bilan kesiladi — kartada bo'sh joy qolmaydi
        Expanded(
          child: Text(
            _previewText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Batafsil — yangilik sahifasiga olib o'tadi
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Batafsil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
