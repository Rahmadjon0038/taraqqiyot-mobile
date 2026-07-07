import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../auth/models/auth_user.dart';
import '../../../auth/models/auth_session.dart';
import '../../../profile/presentation/avatar_picker_modal.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../notifications/presentation/notification_page.dart';
import '../../../../core/services/notification_service.dart';
import 'home_page.dart';
import 'settings_page.dart';

class RoleAwareHomePage extends StatelessWidget {
  const RoleAwareHomePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    final role = _normalizeRole(session.user.role);

    switch (role) {
      case 'teacher':
        return _TeacherShellPage(
          session: session,
          onLogout: onLogout,
          onSessionUpdated: onSessionUpdated,
        );
      case 'admin':
        return _AdminShellPage(
          session: session,
          onLogout: onLogout,
          onSessionUpdated: onSessionUpdated,
        );
      case 'super_admin':
        return _SuperAdminHomePage(
          session: session,
          onLogout: onLogout,
          onSessionUpdated: onSessionUpdated,
        );
      case 'student':
      default:
        return HomePage(
          session: session,
          onLogout: onLogout,
          onSessionUpdated: onSessionUpdated,
        );
    }
  }

  static String _normalizeRole(String role) {
    return role.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }
}

class _TeacherShellPage extends StatefulWidget {
  const _TeacherShellPage({
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  State<_TeacherShellPage> createState() => _TeacherShellPageState();
}

class _TeacherShellPageState extends State<_TeacherShellPage> {
  int _currentIndex = 0;

  List<_RoleTab> get _tabs => [
    _RoleTab(
      title: 'Bosh sahifa',
      icon: Icons.home_rounded,
      builder: (_) => const _CenteredGreeting(
        title: 'Salom, teacher',
        subtitle: 'Hozircha bosh sahifa',
      ),
    ),
    _RoleTab(
      title: 'Mening guruhlarim',
      icon: Icons.menu_book_rounded,
      builder: (_) => const _CenteredGreeting(
        title: 'Mening guruhlarim',
        subtitle: 'Hozircha bo‘sh sahifa',
      ),
    ),
    _RoleTab(
      title: 'Davomat',
      icon: Icons.bar_chart_rounded,
      builder: (_) => const _CenteredGreeting(
        title: 'Davomat',
        subtitle: 'Hozircha bo‘sh sahifa',
      ),
    ),
    _RoleTab(
      title: "To'lovlar",
      icon: LucideIcons.wallet2,
      builder: (_) => const _CenteredGreeting(
        title: "To'lovlar",
        subtitle: 'Hozircha bo‘sh sahifa',
      ),
    ),
    _RoleTab(
      title: 'Sozlamalar',
      icon: LucideIcons.cog,
      builder: (context) => SettingsPage(
        session: widget.session,
        onLogout: widget.onLogout,
        onSessionUpdated: widget.onSessionUpdated,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final displayName = _firstName(
      user.fullName.isEmpty ? user.username : user.fullName,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: _RoleHeader(
                displayName: displayName,
                roleLabel: 'TEACHER',
                user: user,
                session: widget.session,
                onSessionUpdated: widget.onSessionUpdated,
              ),
            ),
          ],
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _tabs[_currentIndex].builder(context),
          ),
        ),
      ),
      bottomNavigationBar: _RoleBottomNavigation(
        currentIndex: _currentIndex,
        items: _tabs,
        showLabels: false,
        compact: false,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _AdminShellPage extends StatefulWidget {
  const _AdminShellPage({
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  State<_AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<_AdminShellPage> {
  int _currentIndex = 0;

  List<_RoleTab> get _tabs => [
    _RoleTab(
      title: 'Bosh sahifa',
      icon: Icons.home_rounded,
      builder: (_) => const _CenteredGreeting(
        title: 'Salom, admin',
        subtitle: 'Hozircha bosh sahifa',
      ),
    ),
    _RoleTab(
      title: 'Sozlamalar',
      icon: LucideIcons.cog,
      builder: (_) => SettingsPage(
        session: widget.session,
        onLogout: widget.onLogout,
        onSessionUpdated: widget.onSessionUpdated,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final displayName = _firstName(
      user.fullName.isEmpty ? user.username : user.fullName,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: _RoleHeader(
                displayName: displayName,
                roleLabel: 'ADMIN',
                user: user,
                session: widget.session,
                onSessionUpdated: widget.onSessionUpdated,
              ),
            ),
          ],
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _tabs[_currentIndex].builder(context),
          ),
        ),
      ),
      bottomNavigationBar: _RoleBottomNavigation(
        currentIndex: _currentIndex,
        items: _tabs,
        showLabels: true,
        compact: true,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _SuperAdminHomePage extends StatelessWidget {
  const _SuperAdminHomePage({
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final displayName = _firstName(
      user.fullName.isEmpty ? user.username : user.fullName,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: _RoleHeader(
                displayName: displayName,
                roleLabel: 'SUPER ADMIN',
                user: user,
                session: session,
                onSessionUpdated: onSessionUpdated,
              ),
            ),
          ],
          body: const _CenteredGreeting(
            title: 'Salom, super admin',
            subtitle: 'Hozircha bosh sahifa',
          ),
        ),
      ),
    );
  }
}

String _firstName(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return value;
  final parts = normalized.split(RegExp(r'\s+'));
  return parts.first;
}

class _RoleHeader extends StatelessWidget {
  const _RoleHeader({
    required this.displayName,
    required this.roleLabel,
    required this.user,
    required this.session,
    required this.onSessionUpdated,
  });

  final String displayName;
  final String roleLabel;
  final AuthUser user;
  final AuthSession session;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D101828),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ProfileAvatar(
              avatarKey: user.avatarKey,
              avatarUrl: user.avatarUrl,
              role: user.role,
              seed: user.username,
              size: 48,
              onTap: () {
                AvatarPickerModal.show(
                  context: context,
                  session: session,
                  onSessionUpdated: onSessionUpdated,
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF182033),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7B8497),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: NotificationService.instance.unreadCount,
              builder: (context, unreadCount, _) {
                return _HeaderActionButton(
                  icon: Icons.notifications_active_outlined,
                  badgeCount: unreadCount,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationPage(session: session),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: const Color(0xFF182033), size: 22),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.brandColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoleBottomNavigation extends StatelessWidget {
  const _RoleBottomNavigation({
    required this.currentIndex,
    required this.items,
    required this.showLabels,
    this.compact = false,
    required this.onTap,
  });

  final int currentIndex;
  final List<_RoleTab> items;
  final bool showLabels;
  final bool compact;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 12 : 10, 0, compact ? 12 : 10, 10),
      padding: EdgeInsets.all(compact ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = index == currentIndex;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(compact ? 16 : 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 8 : 10,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.brandColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(compact ? 16 : 18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: compact ? 22 : 24,
                      color: selected ? Colors.white : const Color(0xFF7A8394),
                    ),
                    if (showLabels) ...[
                      SizedBox(height: compact ? 2 : 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 10.5 : 11.5,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF7A8394),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RoleTab {
  const _RoleTab({
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

class _CenteredGreeting extends StatelessWidget {
  const _CenteredGreeting({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7B8497),
            ),
          ),
        ],
      ),
    );
  }
}
