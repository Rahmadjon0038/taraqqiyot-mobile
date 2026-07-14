import 'package:flutter/material.dart';

/// Faqat dars bo'ladigan kunlarni to'liq nomi bilan ko'rsatadi
/// (masalan: "Seshanba", "Payshanba", "Shanba"). Dars yo'q kunlar chiqmaydi.
class ActiveScheduleDaysWrap extends StatelessWidget {
  const ActiveScheduleDaysWrap({
    super.key,
    required this.scheduleDays,
    required this.color,
  });

  /// Backend schedule.days qiymatlari ("dushanba", "chorshanba", ...)
  final List<String> scheduleDays;
  final Color color;

  static const List<String> _fullNames = [
    'Dushanba',
    'Seshanba',
    'Chorshanba',
    'Payshanba',
    'Juma',
    'Shanba',
    'Yakshanba',
  ];

  @override
  Widget build(BuildContext context) {
    // Hafta tartibida saralangan faol kunlar (1=Du ... 7=Yak)
    final activeWeekdays =
        scheduleDays
            .map(
              (day) => WeekdayPillsRow._nameToWeekday[day.trim().toLowerCase()],
            )
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    if (activeWeekdays.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final day in activeWeekdays)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _fullNames[day - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
      ],
    );
  }
}

/// Hafta kunlari qatori: dars bo'ladigan kunlar [activeColor] bilan ajralib
/// turadi, qolganlari kulrang. Kunlar topilmasa hech narsa chizilmaydi.
class WeekdayPillsRow extends StatelessWidget {
  const WeekdayPillsRow({
    super.key,
    required this.scheduleDays,
    required this.activeColor,
  });

  /// Backend schedule.days qiymatlari ("dushanba", "chorshanba", ...)
  final List<String> scheduleDays;
  final Color activeColor;

  static const List<String> _labels = [
    'Du',
    'Se',
    'Chor',
    'Pay',
    'Ju',
    'Sha',
    'Yak',
  ];

  static const Map<String, int> _nameToWeekday = {
    'dushanba': 1,
    'seshanba': 2,
    'chorshanba': 3,
    'payshanba': 4,
    'juma': 5,
    'shanba': 6,
    'yakshanba': 7,
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  @override
  Widget build(BuildContext context) {
    final activeWeekdays = scheduleDays
        .map((day) => _nameToWeekday[day.trim().toLowerCase()])
        .whereType<int>()
        .toSet();
    if (activeWeekdays.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          Expanded(
            child: Container(
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeWeekdays.contains(day)
                    ? activeColor
                    : const Color(0xFFF1F4F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _labels[day - 1],
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: activeWeekdays.contains(day)
                      ? Colors.white
                      : const Color(0xFF8A93A5),
                ),
              ),
            ),
          ),
          if (day < 7) const SizedBox(width: 5),
        ],
      ],
    );
  }
}
