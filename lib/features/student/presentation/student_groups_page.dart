import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/weekday_pills_row.dart';
import '../../auth/models/auth_session.dart';
import '../data/student_groups_service.dart';
import 'student_group_detail_page.dart';

class StudentGroupsPage extends StatefulWidget {
  const StudentGroupsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<StudentGroupsPage> createState() => _StudentGroupsPageState();
}

class _StudentGroupsPageState extends State<StudentGroupsPage> {
  final StudentGroupsService _service = StudentGroupsService();
  late Future<List<StudentGroupSummary>> _groupsFuture;

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
    return FutureBuilder<List<StudentGroupSummary>>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error;
        final groups = snapshot.data ?? const <StudentGroupSummary>[];

        return RefreshIndicator(
          onRefresh: _reload,
          color: AppTheme.brandColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (isLoading)
                const _GroupsLoadingSkeleton()
              else if (error != null)
                _ErrorState(message: _readErrorMessage(error), onRetry: _reload)
              else if (groups.isEmpty)
                const _EmptyState()
              else
                for (final group in groups) ...[
                  _StudentGroupCard(
                    group: group,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentGroupDetailPage(
                            session: widget.session,
                            groupId: group.groupId,
                            initialScheduleDays: group.scheduleDays,
                            initialScheduleTime: group.scheduleTime,
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

  String _readErrorMessage(Object error) {
    if (error is StudentGroupsException) {
      return error.message;
    }
    return 'Guruhlar yuklanmadi';
  }
}

class _StudentGroupCard extends StatelessWidget {
  const _StudentGroupCard({required this.group, required this.onTap});

  final StudentGroupSummary group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E9F1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Bezak — orqa fonda katta shaffof kitob iconi
              Positioned(
                right: -18,
                bottom: -20,
                child: Transform.rotate(
                  angle: -0.18,
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 96,
                    color: AppTheme.brandColor.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 21,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.groupName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF182033),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_rounded,
                                    size: 13,
                                    color: Color(0xFF8A93A5),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      group.teacherName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF5A6478),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MiniPill(
                          label: group.subjectName,
                          background: const Color(0xFFFBEAE9),
                          foreground: AppTheme.brandColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Wrap — chiplar sig'masa pastki qatorga tushadi
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatChip(
                          icon: Icons.star_rounded,
                          label: '${group.monthlyPoints} ball',
                          background: const Color(0xFFFBEAE9),
                          foreground: AppTheme.brandColor,
                        ),
                        _StatChip(
                          icon: Icons.emoji_events_rounded,
                          label: group.monthlyRank > 0
                              ? '${group.monthlyRank}-o‘rin'
                              : 'O‘rin: -',
                          background: const Color(0xFFF4F6FA),
                          foreground: const Color(0xFF5C6474),
                        ),
                        if (group.scheduleTime.trim().isNotEmpty)
                          _StatChip(
                            icon: Icons.schedule_rounded,
                            label: group.scheduleTime.trim(),
                            background: const Color(0xFFEAF0FF),
                            foreground: const Color(0xFF2563EB),
                          ),
                        _StatChip(
                          icon: Icons.calendar_today_rounded,
                          label: _formatDate(group.createdDate),
                          background: const Color(0xFFF4F6FA),
                          foreground: const Color(0xFF7B8495),
                        ),
                      ],
                    ),
                    // Dars kunlari — faqat dars bor kunlar to'liq nomi bilan
                    if (group.scheduleDays.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ActiveScheduleDaysWrap(
                        scheduleDays: group.scheduleDays,
                        color: AppTheme.brandColor,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + matnli kichik stat chip
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

String _formatDate(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '-';

  final normalized = raw.replaceAll('/', '.');
  final parts = normalized.split('.');
  if (parts.length != 3) return raw;

  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return raw;

  const months = [
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avgust',
    'sentabr',
    'oktabr',
    'noyabr',
    'dekabr',
  ];
  if (month < 1 || month > months.length) return raw;

  return '$day ${months[month - 1]} $year';
}

class _GroupsLoadingSkeleton extends StatelessWidget {
  const _GroupsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          child: const _LoadingCard(),
        );
      }),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 170, height: 18, radius: 10),
          const SizedBox(height: 8),
          _SkeletonBox(width: 130, height: 12, radius: 999),
          const SizedBox(height: 12),
          _SkeletonBox(width: 100, height: 22, radius: 999),
          const SizedBox(height: 12),
          _SkeletonBox(width: double.infinity, height: 44, radius: 14),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF3),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD2CF)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFA70E07),
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: const Column(
        children: [
          Icon(Icons.groups_outlined, color: Color(0xFFA1A8B6), size: 44),
          SizedBox(height: 10),
          Text(
            'Hozircha guruhlaringiz yo\'q',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF182033),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Siz a\'zo bo\'lgan guruhlar shu yerda kartalar ko\'rinishida chiqadi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: Color(0xFF748091),
            ),
          ),
        ],
      ),
    );
  }
}
