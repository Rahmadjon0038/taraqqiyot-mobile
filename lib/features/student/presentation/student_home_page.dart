import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';
import '../../auth/models/auth_session.dart';
import '../../profile/presentation/avatar_picker_modal.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';

class StudentHomePage extends StatelessWidget {
  const StudentHomePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session)? onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    final strings = AppText.of(context);
    final user = session.user;
    final raw = user.raw;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.studentPanel),
        actions: [
          IconButton(
            tooltip: strings.logout,
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(
            name: user.fullName.isEmpty ? user.username : user.fullName,
            subtitle: strings.studentActiveSubtitle,
            accent: const Color(0xFF0F766E),
            avatarKey: user.avatarKey,
            avatarUrl: user.avatarUrl,
            role: user.role,
            seed: user.username,
            onAvatarTap: onSessionUpdated == null
                ? null
                : () {
                    AvatarPickerModal.show(
                      context: context,
                      session: session,
                      onSessionUpdated: onSessionUpdated!,
                    );
                  },
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: strings.studentProfile,
            items: [
              (strings.username, user.username),
              (strings.role, user.role),
              (strings.phone, _text(raw['phone'], strings.unavailable)),
              (strings.phone2, _text(raw['phone2'], strings.unavailable)),
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: strings.studentGroup,
            items: [
              (
                strings.groupName,
                _text(raw['group_name'], strings.unavailable),
              ),
              (
                strings.teacher,
                _text(raw['teacher_name'], strings.unavailable),
              ),
              (
                strings.subject,
                _text(raw['subject_name'], strings.unavailable),
              ),
              (strings.room, _text(raw['room_number'], strings.unavailable)),
              (strings.status, _text(raw['group_status'], strings.unavailable)),
            ],
          ),
        ],
      ),
    );
  }

  static String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.subtitle,
    required this.accent,
    required this.avatarKey,
    required this.avatarUrl,
    required this.role,
    required this.seed,
    this.onAvatarTap,
  });

  final String name;
  final String subtitle;
  final Color accent;
  final String avatarKey;
  final String avatarUrl;
  final String role;
  final String seed;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          ProfileAvatar(
            avatarKey: avatarKey,
            avatarUrl: avatarUrl,
            role: role,
            seed: seed,
            size: 58,
            showBorder: true,
            onTap: onAvatarTap,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.items});

  final String title;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 124,
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
