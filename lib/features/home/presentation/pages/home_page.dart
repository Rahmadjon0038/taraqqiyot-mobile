import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../auth/models/auth_session.dart';
import '../../../auth/models/auth_user.dart';
import '../../../profile/presentation/avatar_picker_modal.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../widgets/home_bottom_navigation.dart';
import 'settings_page.dart';
import '../../../notifications/presentation/notification_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const _sectionTitles = [
    'Asosiy',
    'Mening guruhlarim',
    'Davomat',
    "To'lovlarim",
    'Sozlamalar',
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final displayName = user.fullName.isEmpty ? user.username : user.fullName;
    final firstName = displayName.split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _TopHeader(
              firstName: firstName,
              user: user,
              session: widget.session,
              onSessionUpdated: widget.onSessionUpdated,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: switch (_currentIndex) {
                  0 => const _HomeCenterContent(key: ValueKey('home')),
                  4 => SettingsPage(
                    key: const ValueKey('settings'),
                    session: widget.session,
                    onLogout: widget.onLogout,
                    onSessionUpdated: widget.onSessionUpdated,
                  ),
                  _ => _SectionPlaceholderPage(
                    key: ValueKey('section-$_currentIndex'),
                    title: _sectionTitles[_currentIndex],
                  ),
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HomeBottomNavigation(
        currentIndex: _currentIndex,
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

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.firstName,
    required this.user,
    required this.session,
    required this.onSessionUpdated,
  });

  final String firstName;
  final AuthUser user;
  final AuthSession session;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
              child: Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF182033),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _TopActionButton(
              icon: Icons.notifications_active_outlined,
              showDot: true,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCenterContent extends StatelessWidget {
  const _HomeCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Salom, student',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Color(0xFF182033),
        ),
      ),
    );
  }
}

class _SectionPlaceholderPage extends StatelessWidget {
  const _SectionPlaceholderPage({super.key, required this.title});

  final String title;

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
          const Text(
            'Hozircha bo‘lim sahifasi',
            textAlign: TextAlign.center,
            style: TextStyle(
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

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.onPressed,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
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
        if (showDot)
          Positioned(
            right: 7,
            top: 7,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppTheme.brandColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
