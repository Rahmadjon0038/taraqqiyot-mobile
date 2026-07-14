import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/weekday_pills_row.dart';
import '../../auth/models/auth_session.dart';
import '../data/teacher_service.dart';
import 'teacher_group_detail_page.dart';

/// Teacherning o'z guruhlari ro'yxati.
/// Guruhga kirsa o'quvchilar ro'yxati va ball qo'yish ochiladi.
class TeacherGroupsPage extends StatefulWidget {
  const TeacherGroupsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<TeacherGroupsPage> createState() => _TeacherGroupsPageState();
}

class _TeacherGroupsPageState extends State<TeacherGroupsPage> {
  final TeacherService _service = TeacherService();
  late Future<List<TeacherGroup>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _service.fetchMyGroups(widget.session);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _groupsFuture = _service.fetchMyGroups(widget.session);
    });
    await _groupsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TeacherGroup>>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error;
        final groups = snapshot.data ?? const <TeacherGroup>[];

        return RefreshIndicator(
          onRefresh: _reload,
          color: AppTheme.brandColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.brandColor,
                    ),
                  ),
                )
              else if (error != null)
                _TeacherErrorState(
                  message: error is TeacherServiceException
                      ? error.message
                      : 'Guruhlar yuklanmadi',
                  onRetry: _reload,
                )
              else if (groups.isEmpty)
                const _TeacherEmptyState(
                  icon: Icons.groups_rounded,
                  text: 'Sizga biriktirilgan guruhlar topilmadi',
                )
              else
                for (final group in groups) ...[
                  _TeacherGroupCard(
                    group: group,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TeacherGroupDetailPage(
                            session: widget.session,
                            groupId: group.id,
                            groupName: group.name,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _TeacherGroupCard extends StatelessWidget {
  const _TeacherGroupCard({required this.group, required this.onTap});

  final TeacherGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLessonToday = group.todayLessonsCount > 0;
    final attendanceDone = group.todayAttendanceFullyCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4E9F1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sarlavha: ikonka + nom/fan + bugungi holat nuqtasi + strelka
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF182033),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF0FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              group.subjectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4C63D2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F4F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF6B7386),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Ma'lumotlar paneli: o'quvchilar soni, xona, dars vaqti
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _StatItem(
                        icon: Icons.people_alt_rounded,
                        iconColor: AppTheme.brandColor,
                        value: '${group.studentsCount}',
                        label: 'O\'quvchi',
                      ),
                      const _StatDivider(),
                      _StatItem(
                        icon: Icons.meeting_room_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        value: group.roomNumber.isEmpty
                            ? '—'
                            : group.roomNumber,
                        label: 'Xona',
                      ),
                      const _StatDivider(),
                      _StatItem(
                        icon: Icons.schedule_rounded,
                        iconColor: const Color(0xFF2563EB),
                        value: group.scheduleTime.isEmpty
                            ? '—'
                            : group.scheduleTime,
                        label: 'Dars vaqti',
                      ),
                    ],
                  ),
                ),
                // Dars kunlari: faqat dars bo'ladigan kunlar chiqadi
                if (group.scheduleDays.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ActiveScheduleDaysWrap(
                    scheduleDays: group.scheduleDays,
                    color: AppTheme.brandColor,
                  ),
                ],
                // Bugungi davomat holati
                if (hasLessonToday) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        attendanceDone
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        size: 14,
                        color: attendanceDone
                            ? const Color(0xFF16934F)
                            : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        attendanceDone
                            ? 'Bugungi davomat qilindi'
                            : 'Bugun davomat kutilmoqda',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: attendanceDone
                              ? const Color(0xFF16934F)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ma'lumotlar panelidagi bitta ustun: ikonka + qiymat + yorliq
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A93A5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE4E9F1),
    );
  }
}

class _TeacherEmptyState extends StatelessWidget {
  const _TeacherEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF7B8497)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherErrorState extends StatelessWidget {
  const _TeacherErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 38,
            color: AppTheme.brandColor,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => onRetry(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brandColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Qayta urinish'),
          ),
        ],
      ),
    );
  }
}
