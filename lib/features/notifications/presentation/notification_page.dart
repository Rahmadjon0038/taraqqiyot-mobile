import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'notification_detail_page.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  static const _items = [
    _NotificationItem(
      title: 'Yangi dars qo‘shildi',
      body: 'Bugun soat 19:00 da yangi dars jadvalga qo‘shildi.',
      time: '5 daqiqa oldin',
      category: 'Dars',
      unread: true,
      icon: Icons.school_rounded,
    ),
    _NotificationItem(
      title: 'To‘lov holati yangilandi',
      body: 'Sizning oxirgi to‘lovingiz muvaffaqiyatli qabul qilindi.',
      time: '2 soat oldin',
      category: 'To‘lov',
      unread: true,
      icon: Icons.payments_rounded,
    ),
    _NotificationItem(
      title: 'Yangi xabar',
      body: 'Teacher sizga guruh bo‘yicha xabar qoldirdi.',
      time: 'Kecha',
      category: 'Xabar',
      unread: false,
      icon: Icons.chat_bubble_rounded,
    ),
    _NotificationItem(
      title: 'Davomat yangilandi',
      body: 'Bugungi davomatingiz tizimda belgilandi.',
      time: 'Kecha',
      category: 'Davomat',
      unread: false,
      icon: Icons.fact_check_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Bildirishnomalar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF182033),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.brandColor, Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bildirishnomalar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Muhim xabarlar va yangiliklar shu yerda.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NotificationCard(
                item: item,
                onTap: () {
                  Navigator.of(context).pushNamed(
                    NotificationDetailPage.routeName,
                    arguments: {
                      'title': item.title,
                      'body': item.body,
                      'category': item.category,
                      'time': item.time,
                      'unread': item.unread,
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final _NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.unread
                  ? const Color(0xFFF3C6C6)
                  : const Color(0xFFE7EBF2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: item.unread
                      ? AppTheme.brandColor.withValues(alpha: 0.10)
                      : const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: item.unread
                      ? AppTheme.brandColor
                      : const Color(0xFF7A8394),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF182033),
                            ),
                          ),
                        ),
                        if (item.unread)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppTheme.brandColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F7FB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.category,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5B6577),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.time,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF8A94A6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    required this.unread,
    required this.icon,
  });

  final String title;
  final String body;
  final String time;
  final String category;
  final bool unread;
  final IconData icon;
}
