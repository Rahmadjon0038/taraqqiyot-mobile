import 'package:flutter/material.dart';

class HomeInfoCard extends StatelessWidget {
  const HomeInfoCard({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
    required this.valueColor,
    this.compactValue = false,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final double progress;
  final Color valueColor;
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B101828),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFF667085),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: compactValue ? 2 : 1,
                style: TextStyle(
                  color: valueColor,
                  fontSize: compactValue ? 24 : 26,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: iconBackground.withValues(alpha: 0.8),
              valueColor: AlwaysStoppedAnimation<Color>(valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
