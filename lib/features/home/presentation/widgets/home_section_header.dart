import 'package:flutter/material.dart';

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF101828),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onActionTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  actionLabel,
                  style: const TextStyle(
                    color: Color(0xFFD61F1F),
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF101828),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
