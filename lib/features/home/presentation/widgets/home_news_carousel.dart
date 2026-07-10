import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/home_news_detail_page.dart';

/// Yangilik elementi. Hozircha mock — keyinchalik backend'dan keladi.
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
}

const List<HomeNewsItem> mockHomeNews = [
  HomeNewsItem(
    tag: 'Yangilik',
    title: 'Yozgi intensiv kurslarga qabul boshlandi',
    subtitle: 'Ingliz tili, matematika va IT yo\'nalishlari bo\'yicha',
    body:
        'Taraqqiyot teaching center yozgi intensiv kurslarga qabul boshlanganini '
        'e\'lon qiladi!\n\nIngliz tili, matematika va IT yo\'nalishlari bo\'yicha '
        'tajribali ustozlar bilan qisqa muddatda katta natijaga erishing. '
        'Darslar haftada 5 kun, kichik guruhlarda olib boriladi.\n\n'
        'Ro\'yxatdan o\'tish uchun markazimizga tashrif buyuring yoki '
        'administratorlarga murojaat qiling. Joylar soni cheklangan!',
  ),
  HomeNewsItem(
    tag: 'E\'lon',
    title: 'Iyul oyi reyting g\'oliblari e\'lon qilinadi',
    subtitle: 'Eng ko\'p ball to\'plagan o\'quvchilar taqdirlanadi',
    body:
        'Iyul oyi yakunlari bo\'yicha har bir guruhda eng ko\'p ball to\'plagan '
        'o\'quvchilar aniqlanadi va maxsus sovg\'alar bilan taqdirlanadi.\n\n'
        'Reytingda yuqori o\'rin egallash uchun darslarga faol qatnashing, '
        'uy vazifalarini o\'z vaqtida bajaring va qo\'shimcha ball beruvchi '
        'topshiriqlarni bajaring.\n\nG\'oliblar ro\'yxati oy oxirida ilovada '
        'e\'lon qilinadi. Omad!',
  ),
  HomeNewsItem(
    tag: 'Tadbir',
    title: 'Ota-onalar bilan ochiq eshiklar kuni',
    subtitle: 'Shanba kuni soat 10:00 da markazimizda',
    body:
        'Hurmatli ota-onalar!\n\nShanba kuni soat 10:00 da markazimizda ochiq '
        'eshiklar kuni bo\'lib o\'tadi. Tadbirda farzandingizning o\'quv '
        'natijalari, davomati va reytingi haqida to\'liq ma\'lumot olasiz, '
        'ustozlar bilan yuzma-yuz suhbatlashasiz.\n\nShuningdek, yangi o\'quv '
        'yili rejalari va qo\'shimcha kurslar taqdimoti bo\'ladi. '
        'Barchangizni kutamiz!',
  ),
];

/// Bosh sahifadagi yangiliklar karuseli.
/// Har bir karta newbg.png fonida, "Batafsil" tugmasi yangilik sahifasini ochadi.
class HomeNewsCarousel extends StatefulWidget {
  const HomeNewsCarousel({super.key, this.items = mockHomeNews});

  final List<HomeNewsItem> items;

  @override
  State<HomeNewsCarousel> createState() => _HomeNewsCarouselState();
}

class _HomeNewsCarouselState extends State<HomeNewsCarousel> {
  PageController? _controller;
  Timer? _autoTimer;
  int _currentPage = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      // PageView har sahifani markazlaydi — chetki bo'shliq (1-fraction)*w/2,
      // ichki padding 4px. (w-8)/w fraction bilan chet 4+4 = 8px bo'ladi.
      final width = MediaQuery.of(context).size.width;
      final fraction = width > 32
          ? ((width - 8) / width).clamp(0.5, 1.0)
          : 0.96;
      _controller = PageController(viewportFraction: fraction.toDouble());
      _startAutoAdvance();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoTimer?.cancel();
    if (widget.items.length < 2) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final controller = _controller;
      if (controller == null || !controller.hasClients) return;
      final next = (_currentPage + 1) % widget.items.length;
      controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openDetail(HomeNewsItem item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => HomeNewsDetailPage(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              // Qo'lda surilganda taymer qaytadan boshlanadi
              _startAutoAdvance();
            },
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _NewsCard(item: item, onOpen: () => _openDetail(item)),
              );
            },
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
            Positioned.fill(
              child: Image.asset('assets/newbg.png', fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              // Karta ikki qism: chapda matnlar, o'ng tomon bo'sh qoladi —
              // fondagi logo bemalol ko'rinadi, matn ustiga chiqmaydi
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
        const SizedBox(height: 12),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
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
