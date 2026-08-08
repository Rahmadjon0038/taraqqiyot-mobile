import 'package:flutter/material.dart';

/// Bitta hisobot ustuni (masalan "Uy vazifasi") — teacher qaysi ustunlarni
/// sozlagan/yoqqan bo'lsa, shu ro'yxat aynan o'shani aks ettiradi. Statik
/// 4 ta maydon emas, shuning uchun teacher bir ustunni o'chirsa (masalan
/// "Faollik"), u bu yerda ham darhol yo'qoladi.
class HomeReportMetric {
  const HomeReportMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String key;
  final String label;
  final int value;
  final int maxValue;
}

class HomeReportCard extends StatelessWidget {
  const HomeReportCard({
    super.key,
    required this.monthLabel,
    this.breakdownText,
    this.metrics = const [],
    this.totalScore,
    this.percent,
    this.feedback,
    this.gradingEnabled = true,
    this.onTap,
  });

  final String monthLabel;
  final String? breakdownText;
  final List<HomeReportMetric> metrics;
  final int? totalScore;
  final int? percent;
  final String? feedback;

  /// false — teacher bu darsda "Ball" rejimini tanlagan: foiz/baho
  /// ko'rsatilmaydi, faqat jami ball.
  final bool gradingEnabled;
  final VoidCallback? onTap;

  bool get _hasLessonStats =>
      metrics.isNotEmpty &&
      totalScore != null &&
      (!gradingEnabled || (percent != null && feedback != null));

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E0F1), width: 1.05),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160A1535),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -8,
            child: Icon(
              Icons.calendar_month_rounded,
              size: 66,
              color: const Color(0xFF4F46E5).withValues(alpha: 0.09),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -14,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 58,
              color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x334F46E5),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.assignment_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Oxirgi dars hisoboti',
                            style: TextStyle(
                              color: Color(0xFF5B6478),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_hasLessonStats) ...[
                  const SizedBox(height: 10),
                  _LessonStatsPanel(
                    metrics: metrics,
                    totalScore: totalScore ?? 0,
                    percent: percent ?? 0,
                    feedback: feedback ?? '',
                    gradingEnabled: gradingEnabled,
                    monthLabel: monthLabel,
                  ),
                ] else if (breakdownText != null &&
                    breakdownText!.trim().isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    breakdownText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5B6478),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _DateRow(monthLabel: monthLabel),
                ] else ...[
                  const SizedBox(height: 9),
                  _DateRow(monthLabel: monthLabel),
                ],
                const SizedBox(height: 9),
                const _ActionButton(),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: card,
      ),
    );
  }
}

class _LessonStatsPanel extends StatelessWidget {
  const _LessonStatsPanel({
    required this.metrics,
    required this.totalScore,
    required this.percent,
    required this.feedback,
    required this.gradingEnabled,
    required this.monthLabel,
  });

  final List<HomeReportMetric> metrics;
  final int totalScore;
  final int percent;
  final String feedback;
  final bool gradingEnabled;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final feedbackTone = _feedbackTone(feedback);
    final feedbackLabel = _feedbackLabelUz(feedback);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E0F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < metrics.length; i += 2) ...[
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    metric: metrics[i],
                    color: _metricColor(metrics[i].key, i),
                    icon: _metricIcon(metrics[i].key),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: i + 1 < metrics.length
                      ? _MetricBlock(
                          metric: metrics[i + 1],
                          color: _metricColor(metrics[i + 1].key, i + 1),
                          icon: _metricIcon(metrics[i + 1].key),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9E0F2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    icon: Icons.emoji_events_rounded,
                    label: 'Jami ball',
                    value: '$totalScore',
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                if (gradingEnabled) ...[
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFFD9E0F2),
                  ),
                  Expanded(
                    child: _SummaryStat(
                      icon: Icons.track_changes_rounded,
                      label: 'Foiz',
                      value: '$percent%',
                      color: const Color(0xFF0EA5A0),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFFD9E0F2),
                  ),
                  Expanded(
                    child: _SummaryStat(
                      icon: Icons.verified_rounded,
                      label: 'Baho',
                      value: feedbackLabel,
                      color: _summaryToneColor(feedbackTone),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          _DateRow(monthLabel: monthLabel),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.metric,
    required this.color,
    required this.icon,
  });

  final HomeReportMetric metric;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final label = metric.label;
    final value = metric.value;
    final maxValue = metric.maxValue;
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    final completed = ratio >= 0.999;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD9E0F2)),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 11),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF27304A),
                        fontSize: 8.8,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$value',
                          style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '/ $maxValue',
                          style: const TextStyle(
                            color: Color(0xFF7B8495),
                            fontSize: 8.6,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (completed) ...[
                const SizedBox(width: 4),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: const Color(0xFFE7ECF7),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 12),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7B8495),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: Color(0xFF4F46E5),
            size: 15,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Oxirgi dars:',
                style: TextStyle(
                  color: Color(0xFF7B8495),
                  fontSize: 8.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                monthLabel,
                style: const TextStyle(
                  color: Color(0xFF182033),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF5B5CE7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x334F46E5),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ochish',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 5),
          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
        ],
      ),
    );
  }
}

const List<Color> _metricPalette = [
  Color(0xFF4F46E5),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
];

/// Standart ustunlar uchun ma'lum rang, teacher qo'shgan custom ustunlar
/// uchun palitradan navbat bilan tanlanadi.
Color _metricColor(String key, int index) {
  switch (key) {
    case 'homework':
      return const Color(0xFF4F46E5);
    case 'vocabulary':
      return const Color(0xFF22C55E);
    case 'attendance':
      return const Color(0xFFF59E0B);
    case 'participation':
      return const Color(0xFF3B82F6);
    default:
      return _metricPalette[index % _metricPalette.length];
  }
}

IconData _metricIcon(String key) {
  switch (key) {
    case 'homework':
      return Icons.menu_book_rounded;
    case 'vocabulary':
      return Icons.chat_bubble_rounded;
    case 'attendance':
      return Icons.event_available_rounded;
    case 'participation':
      return Icons.bar_chart_rounded;
    case 'word_memorization':
      return Icons.psychology_alt_rounded;
    case 'sentence_building':
      return Icons.edit_note_rounded;
    case 'listening':
      return Icons.headphones_rounded;
    case 'speaking':
      return Icons.record_voice_over_rounded;
    case 'reading':
      return Icons.menu_book_outlined;
    case 'writing':
      return Icons.create_rounded;
    case 'spelling':
      return Icons.spellcheck_rounded;
    case 'test':
      return Icons.quiz_rounded;
    default:
      return Icons.grade_rounded;
  }
}

enum _FeedbackTone { bad, good, perfect, neutral }

_FeedbackTone _feedbackTone(String feedback) {
  final normalized = feedback.trim().toUpperCase();
  if (normalized.contains('BAD')) return _FeedbackTone.bad;
  if (normalized.contains('PERFECT')) return _FeedbackTone.perfect;
  if (normalized.contains('GOOD')) return _FeedbackTone.good;
  return _FeedbackTone.neutral;
}

String _feedbackLabelUz(String feedback) {
  final normalized = feedback.trim().toUpperCase();
  if (normalized.contains('BAD')) return 'Past';
  if (normalized.contains('PERFECT')) return 'A’lo';
  if (normalized.contains('GOOD')) return 'Yaxshi';
  return feedback.isEmpty ? 'Baholanmagan' : feedback;
}

Color _summaryToneColor(_FeedbackTone tone) {
  return switch (tone) {
    _FeedbackTone.good => const Color(0xFF16A34A),
    _FeedbackTone.perfect => const Color(0xFF4F46E5),
    _FeedbackTone.bad => const Color(0xFFDC2626),
    _FeedbackTone.neutral => const Color(0xFF0F172A),
  };
}
