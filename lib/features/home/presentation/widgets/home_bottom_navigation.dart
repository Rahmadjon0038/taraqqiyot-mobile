import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';

class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _BottomNavItem(icon: Icons.home_rounded),
    _BottomNavItem(icon: Icons.menu_book_rounded),
    _BottomNavItem(icon: Icons.bar_chart_rounded),
    _BottomNavItem(icon: LucideIcons.wallet2),
    _BottomNavItem(icon: LucideIcons.cog),
  ];

  @override
  Widget build(BuildContext context) {
    // SafeArea: Android'da tizimning pastki navigatsiya bari (3 tugmali yoki
    // gesture bar) va iOS home-indicator bar ustiga chiqib qolmasligi kerak
    return SafeArea(
      top: false,
      child: Container(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / _items.length;
          final indicatorWidth = (itemWidth - 8).clamp(50.0, 62.0);
          final indicatorLeft =
              (itemWidth * currentIndex) + ((itemWidth - indicatorWidth) / 2);

          return SizedBox(
            height: 60,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: indicatorLeft,
                  top: 8,
                  width: indicatorWidth,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.brandColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final selected = index == currentIndex;

                    return Expanded(
                      child: DragTarget<int>(
                        onWillAcceptWithDetails: (_) => true,
                        onAcceptWithDetails: (details) {
                          if (details.data != index) {
                            onTap(index);
                          }
                        },
                        builder: (context, candidates, rejects) {
                          final hovered = candidates.isNotEmpty;
                          final iconColor = selected
                              ? Colors.white
                              : hovered
                              ? AppTheme.brandColor
                              : const Color(0xFF7A8394);

                          final iconView = Center(
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              scale: hovered ? 1.05 : 1.0,
                              child: Icon(
                                item.icon,
                                size: 26,
                                color: iconColor,
                              ),
                            ),
                          );

                          final tappable = InkWell(
                            onTap: () => onTap(index),
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(height: 60, child: iconView),
                          );

                          if (selected) {
                            return LongPressDraggable<int>(
                              data: index,
                              feedback: Material(
                                color: Colors.transparent,
                                child: _DragPreview(item: item),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.18,
                                child: tappable,
                              ),
                              child: tappable,
                            );
                          }

                          return tappable;
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({required this.icon});

  final IconData icon;
}

class _DragPreview extends StatelessWidget {
  const _DragPreview({required this.item});

  final _BottomNavItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.brandColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(item.icon, color: Colors.white, size: 24),
    );
  }
}
