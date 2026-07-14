import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../widgets/home_news_carousel.dart';

/// Barcha yangiliklar bitta sahifada o'qiladi.
/// Karuseldan qaysi yangilik bosilsa, sahifa ochilgach o'sha yangilikka
/// avtomatik aylantiriladi.
class HomeNewsListPage extends StatefulWidget {
  const HomeNewsListPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  final List<HomeNewsItem> items;
  final int initialIndex;

  @override
  State<HomeNewsListPage> createState() => _HomeNewsListPageState();
}

class _HomeNewsListPageState extends State<HomeNewsListPage> {
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.items.length; i++) {
      _itemKeys[i] = GlobalKey();
    }
    // Sahifa chizilgach, bosilgan yangilikka silliq o'tamiz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _itemKeys[widget.initialIndex]?.currentContext;
      if (targetContext != null && widget.initialIndex > 0) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFDDE3EE)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: Color(0xFF182033),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Yangiliklar',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF182033),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // Barcha yangiliklar birdaniga chiziladi — bosilgan yangilikka
              // ensureVisible bilan aniq o'tish uchun
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.items.length; i++) ...[
                      _NewsArticleCard(
                        key: _itemKeys[i],
                        item: widget.items[i],
                        highlighted: i == widget.initialIndex,
                      ),
                      if (i < widget.items.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bitta yangilik kartasi: sarlavha + markdown formatidagi matn
class _NewsArticleCard extends StatelessWidget {
  const _NewsArticleCard({
    super.key,
    required this.item,
    this.highlighted = false,
  });

  final HomeNewsItem item;

  /// Karuseldan bosib kelingan yangilik biroz ajralib turadi
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? const Color(0xFFA70E07) : const Color(0xFFE4E9F1),
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.3,
              color: Color(0xFF182033),
            ),
          ),
          if (item.subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 10),
          MarkdownBody(
            data: item.body,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.6,
                color: Color(0xFF3A4454),
              ),
              h1: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF182033),
              ),
              h2: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF182033),
              ),
              h3: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF182033),
              ),
              strong: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF182033),
              ),
              listBullet: const TextStyle(
                fontSize: 14,
                color: Color(0xFF3A4454),
              ),
              blockquoteDecoration: BoxDecoration(
                color: const Color(0xFFF6F8FB),
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: Color(0xFFA70E07), width: 3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
