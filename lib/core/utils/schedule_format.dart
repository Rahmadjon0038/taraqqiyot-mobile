/// Guruh dars jadvalini (kunlar + vaqt) ko'rsatish uchun umumiy formatlash.
/// Backend schedule.days ni o'zbekcha nomlar bilan saqlaydi ("dushanba", ...).
library;

const Map<String, String> _dayShortNames = {
  'dushanba': 'Du',
  'seshanba': 'Se',
  'chorshanba': 'Chor',
  'payshanba': 'Pay',
  'juma': 'Ju',
  'shanba': 'Sha',
  'yakshanba': 'Yak',
  'monday': 'Du',
  'tuesday': 'Se',
  'wednesday': 'Chor',
  'thursday': 'Pay',
  'friday': 'Ju',
  'saturday': 'Sha',
  'sunday': 'Yak',
};

/// ["dushanba", "chorshanba"] -> "Du, Chor"
String formatScheduleDays(List<String> days) {
  final parts = <String>[];
  for (final day in days) {
    final key = day.trim().toLowerCase();
    if (key.isEmpty) continue;
    final short = _dayShortNames[key];
    if (short != null) {
      parts.add(short);
    } else {
      // Noma'lum format bo'lsa bosh harfini katta qilib o'zini ko'rsatamiz
      parts.add('${key[0].toUpperCase()}${key.substring(1)}');
    }
  }
  return parts.join(', ');
}

/// Kunlar va vaqtni bitta yorliqqa yig'adi: "Du, Chor, Ju • 14:00-16:00".
/// Ikkalasi ham bo'sh bo'lsa bo'sh satr qaytadi.
String formatScheduleLabel(List<String> days, String time) {
  final dayLabel = formatScheduleDays(days);
  final timeLabel = time.trim();
  if (dayLabel.isEmpty) return timeLabel;
  if (timeLabel.isEmpty) return dayLabel;
  return '$dayLabel • $timeLabel';
}
