import 'package:flutter/material.dart';

class HomeReportCard extends StatelessWidget {
  const HomeReportCard({
    super.key,
    required this.monthLabel,
    this.breakdownText,
    this.homework,
    this.vocabulary,
    this.attendance,
    this.participation,
    this.totalScore,
    this.percent,
    this.feedback,
    this.onTap,
  });

  final String monthLabel;
  final String? breakdownText;
  final int? homework;
  final int? vocabulary;
  final int? attendance;
  final int? participation;
  final int? totalScore;
  final int? percent;
  final String? feedback;
  final VoidCallback? onTap;

  bool get _hasLessonStats =>
      homework != null &&
      vocabulary != null &&
      attendance != null &&
      participation != null &&
      totalScore != null &&
      percent != null &&
      feedback != null;

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
                    homework: homework ?? 0,
                    vocabulary: vocabulary ?? 0,
                    attendance: attendance ?? 0,
                    participation: participation ?? 0,
                    totalScore: totalScore ?? 0,
                    percent: percent ?? 0,
                    feedback: feedback ?? '',
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
    required this.homework,
    required this.vocabulary,
    required this.attendance,
    required this.participation,
    required this.totalScore,
    required this.percent,
    required this.feedback,
    required this.monthLabel,
  });

  final int homework;
  final int vocabulary;
  final int attendance;
  final int participation;
  final int totalScore;
  final int percent;
  final String feedback;
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
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Uy vazifasi',
                  value: homework,
                  maxValue: 10,
                  color: const Color(0xFF4F46E5),
                  icon: Icons.menu_book_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MetricBlock(
                  label: 'So\'z boyligi',
                  value: vocabulary,
                  maxValue: 10,
                  color: const Color(0xFF22C55E),
                  icon: Icons.chat_bubble_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Davomat',
                  value: attendance,
                  maxValue: 5,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.event_available_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MetricBlock(
                  label: 'Faollik',
                  value: participation,
                  maxValue: 10,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.bar_chart_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                Container(width: 1, height: 30, color: const Color(0xFFD9E0F2)),
                Expanded(
                  child: _SummaryStat(
                    icon: Icons.track_changes_rounded,
                    label: 'Foiz',
                    value: '$percent%',
                    color: const Color(0xFF0EA5A0),
                  ),
                ),
                Container(width: 1, height: 30, color: const Color(0xFFD9E0F2)),
                Expanded(
                  child: _SummaryStat(
                    icon: Icons.verified_rounded,
                    label: 'Baho',
                    value: feedbackLabel,
                    color: _summaryToneColor(feedbackTone),
                  ),
                ),
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
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
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
