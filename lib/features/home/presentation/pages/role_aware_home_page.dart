import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../auth/models/auth_user.dart';
import '../../../auth/models/auth_session.dart';
import '../../../profile/presentation/avatar_picker_modal.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../notifications/presentation/notification_page.dart';
import '../../../super_admin/presentation/super_admin_admins_page.dart';
import '../../../super_admin/presentation/super_admin_attendance_page.dart';
import '../../../super_admin/presentation/super_admin_dashboard_page.dart';
import '../../../teacher/presentation/teacher_attendance_page.dart';
import '../../../teacher/presentation/teacher_dashboard_page.dart';
import '../../../teacher/presentation/teacher_groups_page.dart';
import '../../../teacher/presentation/teacher_payments_page.dart';
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
      // Admin roli mobil ilovada qo'llab-quvvatlanmaydi — faqat veb-panel.
      // Mobilda hozircha student, teacher va super_admin qoladi.
      case 'admin':
        return _UnsupportedRolePage(onLogout: onLogout);
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
      builder: (_) => TeacherDashboardPage(
        key: const ValueKey('teacher-dashboard'),
        session: widget.session,
        onOpenPayments: () {
          setState(() {
            _currentIndex = 3;
          });
        },
      ),
    ),
    _RoleTab(
      title: 'Mening guruhlarim',
      icon: Icons.menu_book_rounded,
      builder: (_) => TeacherGroupsPage(
        key: const ValueKey('teacher-groups'),
        session: widget.session,
      ),
    ),
    _RoleTab(
      title: 'Davomat',
      icon: Icons.bar_chart_rounded,
      builder: (_) => TeacherAttendancePage(
        key: const ValueKey('teacher-attendance'),
        session: widget.session,
      ),
    ),
    _RoleTab(
      title: "To'lovlar",
      icon: LucideIcons.wallet2,
      builder: (_) => TeacherPaymentsPage(
        key: const ValueKey('teacher-payments'),
        session: widget.session,
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

/// Mobil ilovada qo'llab-quvvatlanmaydigan rol (admin) uchun oyna:
/// veb-panelga yo'naltiradi va chiqish tugmasi beradi.
class _UnsupportedRolePage extends StatelessWidget {
  const _UnsupportedRolePage({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.brandColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.desktop_windows_rounded,
                    size: 36,
                    color: AppTheme.brandColor,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Admin paneli mobilda mavjud emas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Admin sifatida ishlash uchun veb-saytdagi '
                  'admin panelidan foydalaning.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8394),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Chiqish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuperAdminHomePage extends StatefulWidget {
  const _SuperAdminHomePage({
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  State<_SuperAdminHomePage> createState() => _SuperAdminHomePageState();
}

class _SuperAdminHomePageState extends State<_SuperAdminHomePage> {
  int _currentIndex = 0;

  List<_RoleTab> get _tabs => [
    _RoleTab(
      title: 'Bosh sahifa',
      icon: Icons.home_rounded,
      builder: (_) => SuperAdminDashboardPage(
        key: const ValueKey('super-admin-dashboard'),
        session: widget.session,
      ),
    ),
    _RoleTab(
      title: 'Davomat',
      icon: Icons.bar_chart_rounded,
      builder: (_) => SuperAdminAttendancePage(
        key: const ValueKey('super-admin-attendance'),
        session: widget.session,
      ),
    ),
    _RoleTab(
      title: 'Adminlar',
      icon: Icons.manage_accounts_rounded,
      builder: (_) => SuperAdminAdminsPage(
        key: const ValueKey('super-admin-admins'),
        session: widget.session,
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
                roleLabel: 'SUPER ADMIN',
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
              size: 42,
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
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  roleLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
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
          width: 40,
          height: 40,
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
            icon: Icon(icon, color: const Color(0xFF182033), size: 20),
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
    // SafeArea: iOS'da bar home-indicator zonasiga va ekranning qayrilgan
    // burchaklariga kirib ketmasligi kerak
    return SafeArea(
      top: false,
      child: Container(
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
